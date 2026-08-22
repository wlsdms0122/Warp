//
//  Loader.swift
//  WarpDocument
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// The door a notation comes through: data in, IR out. It holds the one thing a
// document needs and a procedure does not — the words its constructs are spelled
// with — together with the language it is judged against.
//
// A front end with a document stops at `Value`. A YAML or JSON parser produces
// data; turning that data into a procedure is this one path, and what every
// notation shares is the `Expression` it arrives at rather than the words used
// to get there. A front end with a syntax of its own builds those expressions
// directly and never comes through here, the way a compiler builds its back
// end's instructions rather than printing them and reading them back.
public struct Loader: Sendable {
    // MARK: - Property
    public let language: Language
    public let registry: ConstructRegistry
    public let spellings: SpellingRegistry

    // MARK: - Initializer
    public init(
        language: Language = Language(),
        registry: ConstructRegistry = .standard,
        spellings: SpellingRegistry = .canonical
    ) {
        self.language = language
        self.registry = registry
        self.spellings = spellings
    }

    // Every word this notation reaches on its own — from the readers that spell
    // one, and from the forms registered here. A document written entirely in
    // these spellings still needs them declared somewhere in its link, so a
    // caller assembling a world can ask what it owes before assembling it.
    //
    // What this notation says with a word rather than a construct is a choice it
    // made, so the debt is its own to state. Leaving it unstated would have the
    // bundles read as optional while the spellings quietly required them.
    public var vocabulary: Set<String> {
        registry.vocabulary(with: spellings).union(spellings.vocabulary)
    }

    // MARK: - Public
    // Loading is not decoding: decoding produces a fragment, and only this says
    // the fragment is a module worth linking. It answers with a module rather than
    // something runnable because a document is not runnable — what runs is
    // decided when this module is linked with the others.
    public func load(_ value: Value) throws -> Module {
        let module = try read(ModuleReader.self, from: value).module

        try language.validate(module)

        return module
    }

    // One procedure, for a caller holding a procedure's worth of data rather than a
    // document. A module is how a *file* declares procedures; a caller that has
    // exactly one and already knows what to call it does not have to write an
    // envelope around it to say so.
    public func procedure(from value: Value) throws -> Procedure {
        let procedure = try read(ProcedureReader.self, from: value).procedure

        try language.validate(procedure)

        return procedure
    }

    // Steps read on their own, for a caller assembling a body rather than a
    // document. Deliberately not `load`: a fragment is not a module and carries
    // no signature of its own, so what comes back still has to reach a link
    // inside something that does.
    public func statements(from value: Value) throws -> [Statement] {
        try read([StatementReader].self, from: value).map(\.statement)
    }

    public func statement(from value: Value) throws -> Statement {
        try read(StatementReader.self, from: value).statement
    }

    public func expression(from value: Value) throws -> Expression {
        try read(ExpressionReader.self, from: value).expression
    }

    // MARK: - Private
    private func read<T: Decodable>(_ type: T.Type, from value: Value) throws -> T {
        try T(from: ValueDecoder(
            value: value,
            codingPath: [],
            userInfo: [
                .constructRegistry: registry,
                .spellingRegistry: spellings,
                .loader: self
            ]
        ))
    }
}

public extension CodingUserInfoKey {
    static let constructRegistry = CodingUserInfoKey(rawValue: "warp.constructRegistry")!
    static let loader = CodingUserInfoKey(rawValue: "warp.loader")!
    static let spellingRegistry = CodingUserInfoKey(rawValue: "warp.spellingRegistry")!
}
