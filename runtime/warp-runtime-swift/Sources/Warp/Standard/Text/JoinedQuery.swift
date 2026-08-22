//
//  JoinedQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// Strings written one after another, with a separator between. The separator
// has a default because joining with nothing between is a thing to want, and
// declaring the default is what makes `parts.joined` reachable from a path.
public struct JoinedQuery: Query {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard case let .array(elements) = question.receiver else {
            throw ExecutionError(
                "joined asks \(question.receiver?.type.description ?? "nothing"), expected array"
            )
        }

        guard case let .string(separator) = question.arguments["value"] ?? .string("") else {
            throw ExecutionError("joined asks a non-string separator")
        }

        let written = try elements.map { element -> String in
            guard case let .string(text) = element else {
                throw ExecutionError("joined asks an array holding \(element.type)")
            }

            return text
        }

        return .string(written.joined(separator: separator))
    }

    // MARK: - Private
}
