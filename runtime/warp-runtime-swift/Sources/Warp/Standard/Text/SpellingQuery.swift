//
//  SpellingQuery.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// How any value reads as text. Separate from `TextQuery` because it keeps the
// opposite contract: those transform a string and answer absence for anything
// else, this takes every shape and refuses only nothing.
//
// It is what interpolation is made of, which is why it takes more than a string
// — interpolating a number is the ordinary case. Nothing renders null, because
// completing a sentence with "" would be the language writing what the author
// did not.
public struct SpellingQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        let value = question.receiver ?? .null

        guard value != .null else {
            throw ExecutionError("text asks nothing, and nothing has no spelling")
        }

        return .string(Rendering(value).text)
    }

    // MARK: - Private
}
