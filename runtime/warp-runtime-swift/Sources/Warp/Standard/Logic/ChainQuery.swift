//
//  ChainQuery.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// The boolean connectives, over procedures rather than values. Each link is
// something the link proved answers without running, and this asks them in order
// and stops as soon as the answer is settled — which is the whole of what short
// circuit is.
//
// Taking procedures is what lets these be declarations. A word receives its
// arguments already computed, so a connective over values would have run every
// side before it could decline to.
public struct ChainQuery: Query {
    public enum Chain: Sendable {
        case and
        case or
    }

    // MARK: - Property
    private let chain: Chain

    // MARK: - Initializer
    public init(_ chain: Chain) {
        self.chain = chain
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard case let .array(links) = question.receiver else { return nil }

        for link in links {
            let answer = try question.call(link)

            guard case let .bool(settled) = answer else {
                throw ExecutionError(
                    "a connective asks procedures answering bool, and one"
                        + " answered \(answer.type)"
                )
            }

            // `and` is settled by the first false and `or` by the first true.
            // Everything after it goes unasked, which is why the links arrive
            // unasked in the first place.
            if settled == (chain == .or) { return .bool(settled) }
        }

        return .bool(chain == .and)
    }

    // MARK: - Private
}
