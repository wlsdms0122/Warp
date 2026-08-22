//
//  TestSupport.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

struct TestRecoverableFailure: RecoverableFailure {
    // MARK: - Property
    let message = "the world did not cooperate"

    var payload: Value {
        .object(["type": .string("test"), "message": .string(message)])
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

struct TestFatalError: WarpError {
    // MARK: - Property
    let message = "author mistake"

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

struct FailEffect: Effect {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    func run(_ invocation: Invocation) async throws -> Value {
        guard
            case .bool(true) = try invocation.resolver.resolve(
                invocation.arguments["recoverable"] ?? .literal(.bool(false))
            )
        else {
            throw TestFatalError()
        }

        throw TestRecoverableFailure()
    }

    // MARK: - Private
}

struct FailForm: ConstructForm {
    // MARK: - Property
    static let key = "fail"

    private let recoverable: Bool

    // MARK: - Initializer
    init(from decoder: Decoder) throws {
        self.recoverable = try decoder.singleValueContainer().decode(Bool.self)
    }

    // MARK: - Public
    func expression(boundTo id: String?) -> Warp.Expression {
        .dispatch(
            Dispatch(
                selector: "fail",
                arguments: ["recoverable": .literal(.bool(recoverable))]
            )
        )
    }

    // MARK: - Private
}


func path(_ text: String) -> [PathSegment] {
    try! TemplateParser().parseRefPath(text)
}

// What an expression reads is not a property it carries — the validator walks
// structure and knows which names a body introduces. Asking it is how a test
// asks the same question.
func validates(
    _ expression: Warp.Expression,
    visible: Set<String> = []
) -> Bool {
    do {
        try Validator().validate(
            body: [Statement(id: "probe", expression: expression)],
            visible: visible
        )

        return true
    } catch {
        return false
    }
}

// A caller registers on both sides: the word in the notation's registry, the
// declaration in a module. The split is the point — one says how a document
// spells it, the other says what answers.
extension Module {
    static let testing = Module(
        name: "test",
        procedures: [
            "fail": Procedure(
                signature: Signature(
                    parameters: ["recoverable": Parameter(type: .bool)]
                ),
                implementation: .effect(FailEffect())
            )
        ]
    )
}

extension Loader {
    static let testing = Loader(
        registry: try! ConstructRegistry.standard.registering(FailForm.self),
        spellings: .standard
    )
}


// MARK: - Loading and running

// The entry name these tests link against. Nothing is special about it — which
// procedure a run starts from is an argument to linking.
let entryName = "entry"

extension Loader {
    // Most tests here are about one construct or one reader, not about the
    // envelope a module is written in, so they write a procedure's body and this
    // names it. What the envelope itself accepts is `ModuleNotationTests`.
    //
    // The fixture is a `Value` because that is what a loader takes. Writing YAML
    // here would import a front end, and then a parser bug could fail a reader's
    // test — the imports are supposed to say which layer a test is about.
    func loadProcedure(_ value: Value, named name: String = entryName) throws -> Module {
        try load(["procedures": [name: value]])
    }
}

func run(
    _ modules: [Module],
    entry: String = entryName,
    language: Language = Loader.testing.language,
    arguments: [String: Value] = [:],
    vocabulary: [Module] = Module.standard + [.testing],
    environment: (any Environment)? = nil
) async throws -> [String: Value] {
    let image = try language.link(modules + vocabulary, entry: entry)

    let answer = try await language
        .makeExecutor(environment: environment)
        .run(image, arguments: arguments)

    // This notation spells several named outputs, which the reader lowers to one
    // record — so a test that asks about `outputs["x"]` is asking about a field
    // of the answer, and unwrapping here keeps that phrasing.
    guard case let .object(outputs) = answer else { return [:] }

    return outputs
}


func run(
    _ module: Module,
    entry: String = entryName,
    language: Language = Loader.testing.language,
    arguments: [String: Value] = [:],
    vocabulary: [Module] = Module.standard + [.testing],
    environment: (any Environment)? = nil
) async throws -> [String: Value] {
    try await run(
        [module],
        entry: entry,
        language: language,
        arguments: arguments,
        vocabulary: vocabulary,
        environment: environment
    )
}

// Every procedure a list of modules declares, under its bare name — what a
// resolver's derivations table holds for the words a path may reach.
extension [Module] {
    var procedures: [String: Procedure] {
        reduce(into: [:]) { table, module in
            table.merge(module.procedures) { _, new in new }
        }
    }
}

// MARK: - Conditions

// Equality and the connectives are words, so a test writing one writes the send
// the reader lowers to.
func equals(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .dispatch(Dispatch(receiver: subject, selector: "equal", arguments: ["value": operand]))
}

func differs(_ subject: Warp.Expression, _ operand: Warp.Expression) -> Warp.Expression {
    .dispatch(Dispatch(receiver: subject, selector: "notEqual", arguments: ["value": operand]))
}

func negating(_ condition: Warp.Expression) -> Warp.Expression {
    .dispatch(Dispatch(receiver: condition, selector: "not"))
}

// A connective leaves its later sides unasked, so each arrives as something that
// has not been answered yet.
func every(_ conditions: Warp.Expression...) -> Warp.Expression {
    chained("and", conditions)
}

func some(_ conditions: Warp.Expression...) -> Warp.Expression {
    chained("or", conditions)
}

private func chained(_ selector: String, _ conditions: [Warp.Expression]) -> Warp.Expression {
    .dispatch(
        Dispatch(
            receiver: .array(
                conditions.map { condition in
                    .closure(Procedure(body: [], result: condition))
                }
            ),
            selector: selector
        )
    )
}
