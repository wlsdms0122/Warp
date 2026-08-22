//
//  SequenceQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// Reading an array without saying where. Each takes nothing, so each is
// reachable from a path — `items.first` is the shape these exist for.
public struct SequenceQuery: Query {
    public enum Reading: Sendable {
        case first
        case last
        case reversed
    }

    // MARK: - Property
    private let reading: Reading

    // MARK: - Initializer
    public init(_ reading: Reading) {
        self.reading = reading
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard case let .array(elements) = question.receiver else { return nil }

        switch reading {
        // An empty array has no first, and having none is absence rather than
        // failure — the same answer a missing field gives.
        case .first:
            return elements.first

        case .last:
            return elements.last

        case .reversed:
            return .array(elements.reversed())
        }
    }

    // MARK: - Private
}
