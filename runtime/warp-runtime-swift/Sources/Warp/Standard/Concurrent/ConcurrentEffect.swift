//
//  ConcurrentEffect.swift
//  Warp
//
//  Created by JSilver on 8/22/26.
//

import Foundation

// Running closures at once. A closure is the one body that is safe to run
// beside another — it captured values rather than bindings, writes no name it
// did not declare, and cannot leave past its own edge — so "run these
// concurrently" is a thing a word can be handed, and the grammar does not need
// a construct to say it.
//
// Three words over one machine:
//
// - `all` waits for every closure. A failure fails the whole word, and every
//   piece's failure is reported, keyed by the piece's label — which failures
//   there are is not allowed to depend on timing.
// - `first` answers the first success and asks the rest to stop. Which piece
//   wins is the one fact here that timing decides, and the word's name says so.
// - `map` runs one closure once per element of a collection, and answers in
//   the collection's order — the concurrent reading of what `each` walks.
//
// The rest a sibling ignores: asking is what cancellation is. A piece that
// carries on still finishes, and its answer is discarded.
public struct ConcurrentEffect: Effect {
    // Which completion this word sells. One implementation, because the pieces
    // and the machinery are the same and only what "done" means differs.
    public enum Word: Sendable {
        case all
        case first
        case map
    }

    // What one piece answered — a struct rather than a tuple, which the task
    // group needs for its child results.
    private struct Outcome: Sendable {
        let key: String?
        let position: Int
        let value: Value?
        let failure: (any Error)?

        var label: String { key ?? "[\(position)]" }
    }

    // One closure to run: its name if its author gave one, where it sat, and
    // what it is offered. How a piece is reported is `Outcome`'s to derive.
    private struct Piece: Sendable {
        let key: String?
        let position: Int
        let closure: Closure
        let arguments: [String: Value]
    }

    // MARK: - Property
    private let word: Word

    // The receiver parameter's name, handed in beside the word because the
    // one other place it lives is the Signature this module declares — a
    // ternary here would be a second copy nothing keeps in step.
    private let receiving: String

    // MARK: - Initializer
    public init(_ word: Word, receiving: String) {
        self.word = word
        self.receiving = receiving
    }

    // MARK: - Public
    public func run(_ invocation: Invocation) async throws -> Value {
        switch word {
        case .all:
            let (pieces, keyed) = try closures(of: invocation)
            let outcomes = await outcomes(of: pieces, via: invocation, racing: false)

            let failures = failures(among: outcomes)

            guard failures.isEmpty else { throw failure(among: failures) }

            return answered(outcomes, keyed: keyed)

        case .first:
            // The keys of a record are not wasted on a `first` — the winner's is
            // not reported, but a failure's is: when nothing wins, every
            // piece's failure comes back keyed by the name its author gave it.
            let (pieces, _) = try closures(of: invocation)

            // A `first` with nothing in it has nothing to win it, and waiting for
            // no one answers nothing — refused as the author mistake it is.
            // `all` and `map` answer collections, and a collection may
            // be empty; a `first` answers exactly one thing, so it cannot be.
            guard !pieces.isEmpty else {
                throw ExecutionError("\(name) asks at least one closure, and none arrived")
            }

            let outcomes = await outcomes(of: pieces, via: invocation, racing: true)

            guard let winner = outcomes.first(where: { outcome in outcome.value != nil })?.value else {
                throw failure(among: failures(among: outcomes))
            }

            return winner

        case .map:
            let pieces = try mapped(of: invocation)
            let outcomes = await outcomes(of: pieces, via: invocation, racing: false)

            let failures = failures(among: outcomes)

            guard failures.isEmpty else { throw failure(among: failures) }

            return answered(outcomes, keyed: false)
        }
    }

    // MARK: - Private
    // The receiver — closures to run, as a record for named pieces or an array
    // for positional ones. Which one arrived decides the shape of the answer.
    private func closures(of invocation: Invocation) throws -> ([Piece], keyed: Bool) {
        switch try material(of: invocation) {
        case let .object(fields):
            return (
                try fields.keys.sorted().enumerated().map { position, key in
                    Piece(
                        key: key,
                        position: position,
                        closure: try closure(fields[key] ?? .null, called: key),
                        arguments: [:]
                    )
                },
                keyed: true
            )

        case let .array(elements):
            return (
                try elements.enumerated().map { position, element in
                    Piece(
                        key: nil,
                        position: position,
                        closure: try closure(element, called: "[\(position)]"),
                        arguments: [:]
                    )
                },
                keyed: false
            )

        case let value:
            throw ExecutionError(
                "\(name) asks a record or an array of closures, and was sent \(value.type)"
            )
        }
    }

    // The pieces of `map`: the collection sets how many, the one closure is
    // every piece's body. Each call is offered the element and where it sat,
    // and the closure's own signature says which of those it reads.
    private func mapped(of invocation: Invocation) throws -> [Piece] {
        let material = try material(of: invocation)

        guard case let .array(elements) = material else {
            throw ExecutionError("\(name) walks an array, and was sent \(material.type)")
        }

        let handed = try invocation.resolve("by")

        guard case let .procedure(by) = handed else {
            // Unset and set-to-something-else are different mistakes, and the
            // message says which one was made.
            guard handed != .null else {
                throw ExecutionError("\(name) asks a closure under 'by', and none arrived")
            }

            throw ExecutionError("\(name) asks a closure under 'by', and was sent \(handed.type)")
        }

        return elements.enumerated().map { position, element in
            Piece(
                key: nil,
                position: position,
                closure: by,
                arguments: ["item": element, "index": .int(position)]
            )
        }
    }

    private func material(of invocation: Invocation) throws -> Value {
        guard let receiver = invocation.receiver else {
            return try invocation.resolve(receiving)
        }

        return try invocation.resolver.resolve(receiver)
    }

    private func closure(_ value: Value, called label: String) throws -> Closure {
        guard case let .procedure(closure) = value else {
            throw ExecutionError(
                "\(name) runs closures, and piece \(label) is \(value.type)"
            )
        }

        return closure
    }

    // The qualified spelling, because `first` and `map` are also collection
    // words — a refusal that says which module's word refused is the one a
    // caller can act on.
    private var name: String {
        switch word {
        case .all: "std.concurrent.all"
        case .first: "std.concurrent.first"
        case .map: "std.concurrent.map"
        }
    }

    private func outcomes(
        of pieces: [Piece],
        via invocation: Invocation,
        racing: Bool
    ) async -> [Outcome] {
        await withTaskGroup(of: Outcome.self) { group in
            for piece in pieces {
                group.addTask { await outcome(of: piece, via: invocation) }
            }

            var collected: [Outcome] = []

            for await outcome in group {
                collected.append(outcome)

                // A `first` stops at the first success. The rest are asked to stop
                // rather than made to — a piece that ignores the ask still
                // finishes, and its answer is discarded. Returning without the
                // ask would still await every sibling.
                if racing, outcome.value != nil {
                    group.cancelAll()

                    break
                }
            }

            return collected
        }
    }

    private func outcome(of piece: Piece, via invocation: Invocation) async -> Outcome {
        do {
            return Outcome(
                key: piece.key,
                position: piece.position,
                value: try await answer(piece, via: invocation),
                failure: nil
            )
        } catch {
            return Outcome(key: piece.key, position: piece.position, value: nil, failure: error)
        }
    }

    // What a piece answers, through the environment's isolation boundary —
    // ambient state a caller carries on the task must not reach every piece at
    // once.
    private func answer(_ piece: Piece, via invocation: Invocation) async throws -> Value {
        // The frame carries the bare name — rendering is what brackets it.
        let frame = piece.key ?? "\(piece.position)"

        guard let environment = invocation.environment else {
            return try await invocation.call(
                piece.closure,
                offering: piece.arguments,
                piece: frame
            )
        }

        return try await environment.isolateConcurrentWork {
            try await invocation.call(
                piece.closure,
                offering: piece.arguments,
                piece: frame
            )
        }
    }

    private func failures(among outcomes: [Outcome]) -> [String: any Error] {
        outcomes.reduce(into: [:]) { failures, outcome in
            if let failure = outcome.failure {
                failures[outcome.label] = failure
            }
        }
    }

    // Deterministic by piece label — a dictionary walk must not decide which
    // author mistake gets reported.
    private func failure(among failures: [String: any Error]) -> any Error {
        let ordered = failures.sorted { left, right in left.key < right.key }

        if let authorMistake = ordered.first(where: { _, error in
            !(error is any RecoverableFailure)
        }) {
            return authorMistake.value
        }

        return ConcurrentFailed(failures: failures.mapValues { error in "\(error)" })
    }

    private func answered(_ outcomes: [Outcome], keyed: Bool) -> Value {
        guard keyed else {
            return .array(
                outcomes
                    .sorted { left, right in left.position < right.position }
                    .compactMap(\.value)
            )
        }

        return .object(
            outcomes.reduce(into: [:]) { answers, outcome in
                if let key = outcome.key, let value = outcome.value {
                    answers[key] = value
                }
            }
        )
    }
}
