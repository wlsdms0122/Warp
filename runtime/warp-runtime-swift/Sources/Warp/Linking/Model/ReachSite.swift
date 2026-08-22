//
//  ReachSite.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// A path plus where it was written. `x.foo` is a field where the shape has one
// and a message where it does not, so what a path names is a question about the
// whole link the same way a selector is — and it is asked here for the same
// reason, that a refusal without a path to the statement sends the author
// searching.
struct ReachSite: Sendable {
    // MARK: - Property
    let path: [PathSegment]
    let location: String

    // What each name in scope held where this was written. The walk starts from
    // the head's type, so without this there is no shape to drill into.
    let environment: [String: TypeExpression]

    // MARK: - Initializer
    init(
        path: [PathSegment],
        location: String,
        environment: [String: TypeExpression] = [:]
    ) {
        self.path = path
        self.location = location
        self.environment = environment
    }

    // MARK: - Public
    // MARK: - Private
}
