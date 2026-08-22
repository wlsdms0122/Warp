//
//  ReplacingQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// Every occurrence of one piece of text swapped for another. Literal, not a
// pattern — `regex` is the word that reads patterns, and one word doing both
// would make which of the two an author meant depend on the argument.
public struct ReplacingQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard case let .string(text) = question.receiver else {
            throw ExecutionError(
                "replacing asks \(question.receiver?.type.description ?? "nothing"), expected string"
            )
        }

        guard
            case let .string(sought) = question["value"],
            case let .string(replacement) = question["with"]
        else {
            throw ExecutionError("replacing asks a non-string piece")
        }

        guard !sought.isEmpty else {
            throw ExecutionError("replacing asks an empty piece")
        }

        return .string(text.replacingOccurrences(of: sought, with: replacement))
    }

    // MARK: - Private
}
