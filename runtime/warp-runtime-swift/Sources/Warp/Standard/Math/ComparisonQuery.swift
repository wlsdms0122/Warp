//
//  ComparisonQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// Ordering. Two declarations rather than four: `not` is a language operator, so
// "at least" is `not lessThan`.
public struct ComparisonQuery: Query {
    public enum Ordering: Sendable {
        case lessThan
        case greaterThan
    }

    // MARK: - Property
    private let ordering: Ordering

    // MARK: - Initializer
    public init(_ ordering: Ordering) {
        self.ordering = ordering
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        let operand = question["value"]

        // Strings order too, and lexicographically is what every language means
        // by a string being less than another.
        if case let .string(left) = question.receiver, case let .string(right) = operand {
            return .bool(ordering == .lessThan ? left < right : left > right)
        }

        guard let left = number(question.receiver), let right = number(operand) else {
            throw ExecutionError(
                "comparison asks \(question.receiver?.type.description ?? "nothing") and"
                    + " \(operand.type), expected two numbers or two strings"
            )
        }

        return .bool(ordering == .lessThan ? left < right : left > right)
    }

    // MARK: - Private
    private func number(_ value: Value?) -> Double? {
        switch value {
        case let .int(whole):
            return Double(whole)

        case let .double(real):
            return real

        default:
            return nil
        }
    }
}
