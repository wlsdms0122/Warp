//
//  NegationQuery.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// The opposite of a truth. It takes a value rather than a procedure because
// there is nothing to decline to ask — negation reads its one side whatever the
// answer turns out to be.
public struct NegationQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard case let .bool(truth) = question.receiver else { return nil }

        return .bool(!truth)
    }

    // MARK: - Private
}
