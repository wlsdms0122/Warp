//
//  AbortQuery.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// Leaving instead of answering. The only word that never returns, which is what
// `returns: never` on its declaration says and what lets the arm that leaves
// stay out of the type the arm that stays decides.
//
// The refusal it raises carries the recoverable marker, so `attempt` around it
// catches it and nothing else does.
public struct AbortQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard let message = question.receiver else {
            throw ExecutionError("abort refuses with a message, and none arrived")
        }

        throw Aborted(Rendering(message).text)
    }

    // MARK: - Private
}
