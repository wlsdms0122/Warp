//
//  ContainsQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

public struct ContainsQuery: Query {
    // MARK: - Property

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        // Absence answers false rather than failing: asking whether nothing
        // contains something has an obvious answer.
        guard let receiver = question.receiver, receiver != .null else { return .bool(false) }

        let operand = question["value"]

        switch receiver {
        case let .string(text):
            guard case let .string(part) = operand else {
                throw ExecutionError("contains asks a non-string part of a string")
            }

            return .bool(text.contains(part))

        case let .array(elements):
            return .bool(elements.contains { element in element.matches(operand) })

        default:
            throw ExecutionError(
                "contains asks \(receiver.type), expected string or array"
            )
        }
    }

    // MARK: - Private
}
