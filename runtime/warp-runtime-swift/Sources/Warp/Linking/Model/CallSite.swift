//
//  CallSite.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A message plus where it was written. The location exists only to make a
// refusal answerable: a name that did not resolve, said without the path to the
// statement holding it, sends the author searching the whole document.
struct CallSite: Sendable {
    // MARK: - Property
    let dispatch: Dispatch
    let location: String

    // What each name in scope held where this was written. A call's arguments
    // are mostly references, so without this the types a declaration carries
    // would only ever be checked against literals.
    let environment: [String: TypeExpression]

    // MARK: - Initializer
    init(
        dispatch: Dispatch,
        location: String,
        environment: [String: TypeExpression] = [:]
    ) {
        self.dispatch = dispatch
        self.location = location
        self.environment = environment
    }

    // MARK: - Public
    // MARK: - Private
}
