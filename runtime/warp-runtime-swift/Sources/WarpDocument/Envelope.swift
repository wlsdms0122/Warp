//
//  Envelope.swift
//  WarpDocument
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// What a document says about itself before anything reads what it says.
//
// A program that stays where it was built needs none of this — the thing that
// built it is the thing that runs it. A program that travels does: it arrives at
// something that may be older than the program is, may not have the words the
// program calls, and cannot ask the sender anything. Both questions have to be
// answerable from the bytes alone, and both have to be answerable *before* the
// program runs, because half-running one is worse than refusing it.
public enum Envelope {
    // MARK: - Property
    // Which shapes a reader has to understand. It goes up when a shape is added
    // or an existing one changes what it means, and does not move for a new word
    // — a word is vocabulary, and vocabulary is what `needs` is for.
    //
    // A document that says nothing is read as the earliest, which is what lets
    // one written before this existed still be read.
    //
    // Nothing has shipped, so there is nothing old to hold a number for — every
    // change before the first release folds into this one. The counter starts
    // moving when a document exists somewhere this code does not control.
    public static let version = 1
    public static let earliest = 1

    public static let versionKey = "warp"
    public static let needsKey = "needs"

    // MARK: - Public
    // The words a document sends and does not declare. Every one has to be
    // declared by something in the link or the program cannot run, so this is
    // what a reader needs from elsewhere, listed rather than discovered.
    //
    // Sent, not reached. A path reaches words too — `x.count` is one — but only
    // ones that answer without running, since that is the whole of what makes a
    // path safe to walk. So what is listed here is everything the program can do
    // that touches anything, and a caller reading it is reading the bounds of
    // what it is about to allow.
    public static func needs(of module: Module) -> Set<String> {
        // A constant is an expression, so it sends words like any other. Missing
        // them would understate what a program needs, and the list is only worth
        // having if it can be believed.
        module.constants.values
            .reduce(into: Set()) { sent, constant in
                sent.formUnion(selectors(in: constant))
            }
            .union(
                module.procedures.values.reduce(into: Set()) { sent, procedure in
                    guard case let .body(block) = procedure.implementation else { return }

                    sent.formUnion(selectors(in: block))
                }
            )
            .subtracting(module.procedures.keys)
    }

    // MARK: - Private
    private static func selectors(in block: Block) -> Set<String> {
        selectors(in: block.body).union(block.result.map(selectors(in:)) ?? [])
    }

    private static func selectors(in body: [Statement]) -> Set<String> {
        body.reduce(into: []) { sent, statement in
            sent.formUnion(selectors(in: statement.expression))
        }
    }

    private static func selectors(in expression: Expression) -> Set<String> {
        switch expression {
        case .literal, .reference:
            return []

        case let .array(array):
            return array.reduce(into: Set()) { sent, element in
                sent.formUnion(selectors(in: element))
            }

        case let .record(record):
            return record.values.reduce(into: Set()) { sent, field in
                sent.formUnion(selectors(in: field))
            }

        // A closure is a body that runs later, and what it sends is still sent.
        case let .closure(procedure):
            guard case let .body(block) = procedure.implementation else { return [] }

            return selectors(in: block)

        case let .invoke(callee, arguments):
            return arguments.values.reduce(into: selectors(in: callee)) { sent, argument in
                sent.formUnion(selectors(in: argument))
            }

        case let .block(block):
            return selectors(in: block)

        case let .conditional(condition, then, otherwise):
            return selectors(in: condition)
                .union(selectors(in: then))
                .union(otherwise.map(selectors(in:)) ?? [])

        case let .loop(condition, body, _):
            return selectors(in: condition).union(selectors(in: body))

        case let .iteration(material, body, _):
            return selectors(in: material).union(selectors(in: body))

        case let .attempt(block, rescue, _):
            return selectors(in: block).union(selectors(in: rescue))

        case let .dispatch(dispatch):
            var sent: Set<String> = [dispatch.selector]

            dispatch.receiver.map { receiver in sent.formUnion(selectors(in: receiver)) }
            dispatch.arguments.values.forEach { argument in
                sent.formUnion(selectors(in: argument))
            }

            return sent

        case let .leave(leave):
            return leave.value.map(selectors(in:)) ?? []
        }
    }
}
