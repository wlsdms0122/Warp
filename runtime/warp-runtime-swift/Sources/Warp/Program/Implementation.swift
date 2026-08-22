//
//  Implementation.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// How a procedure does what it declares. A body of statements, or native code.
//
// This is the whole of what separates a native word from a procedure: which
// language the body is written in. Both are the same concept answered two ways,
// so they share one container.
//
// There is one kind of declaration, and this is the axis it varies on. A module
// of native words links like any other, and a document calling one is doing what
// a document calling a procedure does.
public enum Implementation: Sendable {
    case body(Block)

    // Answers without running anything. Pure and synchronous, which is what
    // lets it be asked inside a condition and inside a path.
    case query(any Query)

    // Answers by reaching outside the run. Asynchronous, so it cannot be asked
    // where a value is merely read.
    case effect(any Effect)

    // MARK: - Property
    // Whether this answers without running. For a body it is not knowable from
    // the case alone — what it calls decides — so the linker computes it and
    // this says only what a native declares about itself.
    public var isNativelyPure: Bool? {
        switch self {
        case .query:
            return true

        case .effect:
            return false

        case .body:
            return nil
        }
    }

    public var block: Block? {
        guard case let .body(block) = self else { return nil }

        return block
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
