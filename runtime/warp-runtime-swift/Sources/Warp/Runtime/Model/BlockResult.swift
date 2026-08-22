//
//  BlockResult.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// What running a body produced — the scope with every binding, and the last
// statement's value, which is what a block speaks with when it declares no
// result of its own.
public struct BlockResult: Sendable {
    // MARK: - Property
    public let scope: Scope
    public let lastResult: Value

    // MARK: - Initializer
    init(scope: Scope, lastResult: Value) {
        self.scope = scope
        self.lastResult = lastResult
    }

    // MARK: - Public
    // MARK: - Private
}
