//
//  Query.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A procedure implemented natively that answers without running anything —
// `count`, `contains`, whatever a module ships. Pure and synchronous, which is
// what lets it be asked inside a condition and inside a path: `items.count`
// is this sent to `items` with no arguments.
//
// It carries no name and no signature. Both belong to the `Procedure` that has
// this as its implementation — the name is the key its module declares it under,
// the same as any other declaration, and the signature is what a call site is
// checked against whichever way the body is written.
//
// Answering nil means the word does not apply to that receiver's shape. It is
// not a failure — a path that derives nothing reads as absent, the same as a
// field that was never set.
public protocol Query: Sendable {
    // Checks arguments that are already constant, at load. Type is the
    // signature's business; this is for what a type cannot say — that a regex
    // pattern compiles. An author typo surfaces before any run.
    func validate(_ arguments: [String: Value]) throws

    func evaluate(_ question: Question) throws -> Value?
}

public extension Query {
    func validate(_ arguments: [String: Value]) throws {
    }
}
