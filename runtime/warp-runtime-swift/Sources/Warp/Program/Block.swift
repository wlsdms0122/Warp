//
//  Block.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Statements run in order, then one expression answers.
//
// A block with no result answers nothing. The alternative — the last statement's
// value — puts the answer somewhere nothing points at, so appending a statement
// changes what the block is worth and the author who appended it wrote nothing
// that says so. Naming the answer costs one line and says which line it is.
public struct Block: Sendable {
    // MARK: - Property
    public let body: [Statement]
    public let result: Expression?

    // MARK: - Initializer
    public init(body: [Statement], result: Expression? = nil) {
        self.body = body
        self.result = result
    }

    // MARK: - Public
    // MARK: - Private
}
