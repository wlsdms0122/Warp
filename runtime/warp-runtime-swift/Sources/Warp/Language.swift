//
//  Language.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// The door. Reading, judging, linking and running are four things with four
// types, and this is the one name that says they are one language — a caller
// that goes through it cannot pair a validator with a linker that disagreed.
//
// It holds nothing — no vocabulary, no ambient heads. Either would be
// configuration standing in for a declaration: a word would be a setting rather
// than something a program declares, and a name could resolve to what no
// declaration mentioned.
public struct Language: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    public init() { }

    // MARK: - Public
    public func makeExecutor(
        observer: (any ExecutionObserver)? = nil,
        environment: (any Environment)? = nil
    ) -> Executor {
        Executor(
            observer: observer,
            environment: environment
        )
    }

    // The second judgement, and the one validation cannot make: a module is
    // checked against itself, an image is checked across every module given.
    //
    // What to link is the caller's statement — the whole world at once — and
    // `entry` names which declaration this run starts from. There is no default:
    // a language that guessed which procedure was meant would hold an opinion it
    // was never given.
    //
    // A bundled vocabulary is one of those modules, and a caller that leaves it
    // out is a caller whose `count` does not resolve.
    public func link(_ modules: [Module], entry: String) throws -> Image {
        try Linker().link(modules, entry: entry)
    }

    public func validate(_ module: Module) throws {
        try Validator().validate(module)
    }

    public func validate(_ procedure: Procedure) throws {
        try Validator().validate(procedure)
    }

    // MARK: - Private
}
