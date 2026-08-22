//
//  Closure.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// A procedure together with the scope it was written in. This is what a
// procedure literal answers with, and it is the only shape a value can have that
// can be called.
//
// The captured scope is what makes it a closure rather than a body: a literal
// written inside a loop round sees that round's names forever after, and calling
// it later does not put it back where the caller stands. Scope is lexical.
//
// A declared procedure and an anonymous one are the same `Procedure`. What
// separates them is only whether a module declares it under a name, which is a
// fact about the module rather than about the thing declared.
public struct Closure: Sendable {
    // MARK: - Property
    public let procedure: Procedure
    public let captured: Scope

    // MARK: - Initializer
    public init(procedure: Procedure, captured: Scope) {
        self.procedure = procedure
        self.captured = captured
    }

    // MARK: - Public
    // MARK: - Private
}
