//
//  TypeFrame.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What inference needs beyond the body it is reading: what every declaration in
// the link answers with, and what every name in it stands for.
//
// One value rather than two arguments threaded through every walk, because they
// are one fact — the link's answer to "what does this name mean" — read from two
// sides.
struct TypeFrame: Sendable {
    // MARK: - Property
    // Keyed by the resolved selector for a call, and by the bare name a path
    // writes for a word a path may reach. The two spellings answer the same
    // question in the two places it gets asked.
    //
    // Whole signatures rather than what each answers, because a declaration with
    // a hole in it does not answer anything until a call site fills it — and
    // what fills it is read from the parameters.
    let signatures: [String: Signature]

    let types: TypeTable

    // Every declaration that answers without running, by resolved selector. A
    // closure literal is judged against this, so what a body is written to call
    // decides whether it fits a slot asking for purity.
    let pure: Set<String>

    // MARK: - Initializer
    // MARK: - Public
    // What a name answers with, before any hole in it is filled. Enough for a
    // path, which sends no arguments and so fills nothing.
    func returns(of name: String) -> TypeExpression? {
        signatures[name]?.returns
    }

    // A named type stands for what it was declared as. Inference walks into
    // shapes, so it has to look through a name to find one.
    func resolve(_ type: TypeExpression) -> TypeExpression {
        guard case let .named(name) = type, let declared = types.resolve(name) else {
            return type
        }

        return resolve(declared)
    }

    // MARK: - Private
}
