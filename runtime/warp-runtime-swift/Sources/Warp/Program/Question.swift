//
//  Question.swift
//  Warp
//
//  Created by JSilver on 8/18/26.
//

import Foundation

// What a word is asked: the value it was sent to, and the arguments it was sent
// with, already settled against the declaration.
//
// One value rather than a parameter list because what a question carries is not
// finished. A type in force, a type argument, the table a named type resolves
// in — each of those would be a new parameter, and a new parameter rewrites
// every word anyone has written. A field on this rewrites none of them.
// `Effect` takes `Invocation` for the same reason; this is the pure half, so it
// carries values where that one carries expressions.
public struct Question: Sendable {
    // MARK: - Property
    // What this was sent to, or nil where it was sent to nothing. Nil rather
    // than null because a word decides for itself what being sent to nothing
    // means — `contains` says false rather than failing.
    public let receiver: Value?

    public let arguments: [String: Value]

    // The way back in, for a word handed a procedure. It is here rather than
    // handed to `Query.evaluate` because most words never call anything, and a
    // parameter every word declares to serve the few that do is a parameter in
    // the wrong place.
    private let resolver: Resolver?

    // MARK: - Initializer
    public init(
        receiver: Value? = nil,
        arguments: [String: Value] = [:],
        resolver: Resolver? = nil
    ) {
        self.receiver = receiver
        self.arguments = arguments
        self.resolver = resolver
    }

    // MARK: - Public
    // What a named argument holds. An argument nobody wrote and one written as
    // null are the same fact here, the same as they are everywhere else.
    public subscript(name: String) -> Value {
        arguments[name] ?? .null
    }

    // Running a procedure this word was handed. What may be handed is what the
    // link proved answers without running, which a word states by declaring the
    // parameter `pure procedure` — so reaching here means the judgement was
    // already made.
    public func call(_ procedure: Value, with arguments: [String: Value] = [:]) throws -> Value {
        guard case let .procedure(closure) = procedure else {
            throw ExecutionError(
                "this call names \(procedure.type), and only a procedure can be called"
            )
        }

        guard let resolver else {
            throw ExecutionError("this question was asked with no way back into the run")
        }

        return try resolver.call(closure, with: arguments)
    }
}
