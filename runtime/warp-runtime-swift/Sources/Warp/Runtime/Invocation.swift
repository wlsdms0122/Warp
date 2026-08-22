//
//  Invocation.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// A message in flight: what was sent, where it was sent from, and the doors back
// into the runtime an effect needs to answer it.
//
// Arguments arrive unresolved. An effect decides for itself what to settle and
// when — some it must have as values before it can act, and a block must not be
// evaluated until the effect decides it should run.
public struct Invocation: Sendable {
    // MARK: - Property
    public let selector: String
    public let receiver: Expression?
    public let arguments: [String: Expression]

    // Where the run was when this was sent, as everything it went through to
    // get here. Provenance, not meaning: a word does not know the statement it
    // was written in, but a log line and a refusal both want to say where they
    // are.
    public let trace: Trace

    public let scope: Scope

    public var resolver: Resolver { resolver(for: scope) }

    public var environment: (any Environment)? { executor.environment }

    private let executor: Executor

    // MARK: - Initializer
    init(
        selector: String,
        receiver: Expression?,
        arguments: [String: Expression],
        trace: Trace,
        scope: Scope,
        executor: Executor
    ) {
        self.selector = selector
        self.receiver = receiver
        self.arguments = arguments
        self.trace = trace
        self.scope = scope
        self.executor = executor
    }

    // MARK: - Public
    // An argument settled in the sending scope. An argument that was not written
    // reads as null, the same as a reference that names nothing — an effect
    // declares what it requires in its signature, and the linker is what
    // enforces it, so reaching here means the author was allowed to omit this.
    public func resolve(_ name: String) throws -> Value {
        guard let argument = arguments[name] else { return .null }

        return try resolver.resolve(argument)
    }

    // Nil for an argument that is absent or null, rather than the empty string
    // stringifying null would give — "unset" and "set to nothing" are different
    // instructions to a caller.
    public func string(_ name: String) throws -> String? {
        switch try resolve(name) {
        case .null:
            return nil

        case let value:
            return resolver.stringify(value)
        }
    }

    public func resolver(for scope: Scope) -> Resolver {
        Resolver(scope: scope, derivations: executor.derivations, types: executor.types)
    }

    public func evaluate(_ expression: Expression, in scope: Scope) async throws -> Value {
        try await executor.evaluate(expression, in: scope, at: trace)
    }

    public func run(_ block: Block, in scope: Scope) async throws -> Value {
        try await executor.run(block, in: scope, at: trace)
    }

    public func run(_ body: [Statement], in scope: Scope) async throws -> BlockResult {
        try await executor.run(body, in: scope, at: trace)
    }

    public func call(
        procedure name: String,
        arguments: [String: Value]
    ) async throws -> Value {
        try await executor.call(procedure: name, arguments: arguments, in: scope)
    }

    // Calling a closure the word was handed as a value. The label names which
    // piece of the word's work this call is, so a refusal from inside says
    // where it happened rather than only which word was running.
    public func call(
        _ closure: Closure,
        offering arguments: [String: Value],
        piece label: String? = nil
    ) async throws -> Value {
        try await executor.call(
            closure,
            offering: arguments,
            at: label.map { name in trace.appending(.piece(name)) } ?? trace
        )
    }

    // MARK: - Private
}
