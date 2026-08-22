//
//  StartsWithQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

public struct StartsWithQuery: Query {
    // MARK: - Property

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard let receiver = question.receiver, receiver != .null else { return .bool(false) }

        guard case let .string(prefix) = question["value"] else {
            return .bool(false)
        }

        guard case let .string(text) = receiver else {
            throw ExecutionError("startsWith asks \(receiver.type), expected string")
        }

        return .bool(text.hasPrefix(prefix))
    }

    // MARK: - Private
}
