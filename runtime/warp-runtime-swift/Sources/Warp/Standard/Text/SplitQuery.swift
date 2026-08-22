//
//  SplitQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// A string cut on a separator. Empty pieces are kept: what a document usually
// wants from splitting is the shape of the text, and dropping the empty ones
// would be an opinion about the text rather than a reading of it.
public struct SplitQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard case let .string(text) = question.receiver else {
            throw ExecutionError(
                "split asks \(question.receiver?.type.description ?? "nothing"), expected string"
            )
        }

        guard case let .string(separator) = question["value"], !separator.isEmpty else {
            throw ExecutionError("split asks an empty separator")
        }

        return .array(
            text
                .components(separatedBy: separator)
                .map(Value.string)
        )
    }

    // MARK: - Private
}
