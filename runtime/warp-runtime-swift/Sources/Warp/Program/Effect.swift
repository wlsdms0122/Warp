//
//  Effect.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A procedure implemented natively that answers by reaching outside the run —
// anything with a clock, a device or another process behind it. Same
// declaration, same dispatch as a query; the difference is that it runs, so it
// is asynchronous and cannot be asked inside a condition.
//
// An effect is declared, not embedded. The grammar stays closed — a module adds
// vocabulary, never a new kind of expression, so nothing installed can quietly
// redefine what `loop` means.
public protocol Effect: Sendable {
    func run(_ invocation: Invocation) async throws -> Value
}
