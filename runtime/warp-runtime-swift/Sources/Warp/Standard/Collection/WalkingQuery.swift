//
//  WalkingQuery.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// Walking an array with a procedure the caller wrote. Each declares its
// procedure parameter `pure procedure`, so what arrives is something the link
// proved answers without running — which is what lets these be words rather
// than constructs the grammar had to grow.
//
// What a walk hands the procedure it was given is named the way `iteration`
// names what it binds: the element is `item`, and a reduction's answer so far is
// `carried`. Fixed rather than taken from the order the procedure declared them
// in, because a declaration is a mapping and a mapping has no order.
public struct WalkingQuery: Query {
    public enum Walk: Sendable {
        case map
        case filter
        case reduce
    }

    // MARK: - Property
    private let walk: Walk

    // MARK: - Initializer
    public init(_ walk: Walk) {
        self.walk = walk
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard case let .array(elements) = question.receiver else { return nil }

        let body = question["value"]

        switch walk {
        case .map:
            return .array(
                try elements.map { element in
                    try question.call(body, with: ["item": element])
                }
            )

        case .filter:
            return .array(
                try elements.filter { element in
                    let verdict = try question.call(body, with: ["item": element])

                    guard case let .bool(kept) = verdict else {
                        throw ExecutionError(
                            "filter asks a procedure answering bool, and this one"
                                + " answered \(verdict.type)"
                        )
                    }

                    return kept
                }
            )

        case .reduce:
            return try elements.reduce(question["from"]) { carried, element in
                try question.call(body, with: ["carried": carried, "item": element])
            }
        }
    }

    // MARK: - Private
}
