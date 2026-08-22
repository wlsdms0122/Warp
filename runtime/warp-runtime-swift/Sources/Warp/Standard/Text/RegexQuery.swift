//
//  RegexQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

public struct RegexQuery: Query {
    // MARK: - Property

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    // A pattern that does not compile is an author mistake, and a constant one
    // is knowable before the run — which is the whole reason a word gets to
    // check its own arguments at load.
    public func validate(_ arguments: [String: Value]) throws {
        guard
            case let .string(pattern) = arguments["value"] ?? .null,
            (try? NSRegularExpression(pattern: pattern)) != nil
        else {
            throw ValidationError("regex needs a valid string pattern")
        }
    }

    public func evaluate(_ question: Question) throws -> Value? {
        guard let receiver = question.receiver, receiver != .null else { return .bool(false) }

        guard case let .string(pattern) = question["value"] else {
            return .bool(false)
        }

        guard case let .string(text) = receiver else {
            throw ExecutionError("regex asks \(receiver.type), expected string")
        }

        return .bool(text.range(of: pattern, options: .regularExpression) != nil)
    }

    // MARK: - Private
}
