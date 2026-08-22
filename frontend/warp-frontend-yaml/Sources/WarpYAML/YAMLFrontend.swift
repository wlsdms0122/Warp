//
//  YAMLFrontend.swift
//  WarpYAML
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Warp
import WarpDocument

// A front end is a function from what a person wrote to a document, and it ends
// where the document begins. What comes out of here is the canonical document —
// every spelling this notation offers has been spent, so two runtimes reading
// the result have nothing left to agree about but the document format itself.
//
// There is deliberately no way to get a runnable thing out of a front end. An
// application that authors and runs in one process feeds this output to its
// runtime's loader — two calls, and the second one is the same call a program
// arriving from anywhere else comes through. One door for arriving code is the
// point; a second, warmer door for local code is how the two doors drift apart.
//
// Note what the dependency on `WarpDocument` is for: this front end currently
// *borrows* the runtime's spelled reader to lower its sugar, and gives the
// canonical writer the result. The boundary is already the document; the
// borrowing is an implementation on the way to a front end that lowers its own
// spellings against the specification alone.
public struct YAMLFrontend: Sendable {
    // MARK: - Property
    private let parser: YAMLParser
    private let loader: Loader
    private let writer: Writer

    // MARK: - Initializer
    // No knobs. The one thing a caller could ask this type to vary — which
    // construct words exist — is a departure from the portable document, and a
    // host that wants one composes `YAMLParser` with its own `Loader` instead.
    public init() {
        let loader = Loader(spellings: .standard)

        self.parser = YAMLParser()
        self.loader = loader

        // The words read and the words written are one table, said once —
        // left to two defaults, they would only ever agree by coincidence.
        self.writer = Writer(registry: loader.registry)
    }

    // MARK: - Public
    public func document(from text: String) throws -> Value {
        try document(of: try parser.parse(text))
    }

    public func document(from data: Data) throws -> Value {
        try document(of: try parser.parse(data))
    }

    // MARK: - Private
    // Text in, document out. The middle is a validated module — a front end
    // that shipped a document it never checked would be moving refusals from
    // the author's desk to the arrival, which is the wrong direction.
    private func document(of parsed: Value) throws -> Value {
        try writer.value(of: try loader.load(parsed))
    }
}
