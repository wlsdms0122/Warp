//
//  CountQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// How many. Answers nil for shapes that have no count, which is what makes
// `x.count` read as absent rather than fail when `x` is a number.
public struct CountQuery: Query {
    // MARK: - Property

    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        switch question.receiver {
        case let .array(elements):
            return .int(elements.count)

        case let .string(text):
            return .int(text.count)

        case let .object(fields):
            return .int(fields.count)

        // Bytes have a length the way text has a count — and unlike text, no
        // Unicode question about what "one" means.
        case let .bytes(bytes):
            return .int(bytes.count)

        default:
            return nil
        }
    }

    // MARK: - Private
}
