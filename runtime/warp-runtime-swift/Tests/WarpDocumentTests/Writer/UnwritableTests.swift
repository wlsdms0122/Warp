//
//  UnwritableTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// The shapes a document has no way to say.
//
// All of them are built rather than parsed — a document could not make one, so
// nothing here comes back from a reader. They are reachable because assembling
// the language's shapes directly is a supported way to write a program, and
// writing one out is what this whole direction exists for. What matters is that
// each is refused: a document that came back meaning something else would be
// worse than no document, because nothing downstream could tell.
@Suite("A program shape with no document is refused rather than approximated")
struct UnwritableTests {
    // MARK: - Property
    private let sut = Writer()
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a procedure held as a value is not data")
    func aProcedureValueIsNotData() {
        // Given — a closure has already taken a scope with it, and a document
        // carries neither code nor the scope it closed over
        let held = Value.procedure(
            Closure(procedure: Procedure(body: []), captured: Scope())
        )

        // When / Then
        #expect {
            try sut.value(of: module(binding: .literal(held)))
        } throws: { error in
            "\(error)".contains("not data")
        }

        // And no deeper in either — a list of them is no more writable
        #expect(throws: WritingError.self) {
            try sut.value(of: module(binding: .literal(.array([held]))))
        }
    }

    @Test("a record whose fields are read as a form has no document")
    func aRecordThatWouldReadAsAFormIsRefused() {
        // Given — a record of expressions cannot be quoted, because `{ value: }`
        // says the fields are data rather than things to work out
        let sut = try? sut.value(
            of: module(binding: .record(["ref": .literal(.string("not-a-path"))]))
        )

        // Then
        #expect(sut == nil)
    }

    @Test("a record in a condition slot is refused where its fields spell an operator")
    func aRecordThatWouldReadAsASpellingIsRefused() throws {
        // Given — this is the one that would not have announced itself. Written
        // plainly, `{ of: …, is: … }` in a condition slot is read back as a
        // comparison, so the program that came out would run where the one that
        // went in was refused.
        let condition = Warp.Expression.record([
            "of": .reference(path("word")),
            "is": .literal(.string("hey"))
        ])

        // When / Then
        #expect {
            try sut.value(of: module(binding: .conditional(
                condition,
                then: Block(body: [], result: .literal(.string("yes"))),
                else: nil
            )))
        } throws: { error in
            "\(error)".contains("read as a form")
        }

        // The same record anywhere else is ordinary — only a condition slot
        // reads those words
        #expect(throws: Never.self) {
            try sut.value(of: module(binding: condition))
        }
    }

    @Test("a declared type named like a built-in has no document")
    func aTypeNamedLikeABuiltinIsRefused() {
        // Given — nothing stops a module declaring a type called `int`; a
        // document just reads the name it knows as the type it knows
        #expect(throws: WritingError.self) {
            try sut.value(of: TypeExpression.named("int"))
        }

        #expect(throws: Never.self) {
            try sut.value(of: TypeExpression.named("Task"))
        }
    }

    @Test("a record type shaped like a procedure type has no document")
    func aRecordTypeThatWouldReadAsAProcedureIsRefused() {
        // Given — a record and a procedure are both written as a mapping, and
        // the key that tells them apart is the procedure's
        #expect(throws: WritingError.self) {
            try sut.value(of: TypeExpression.record(["procedure": .int]))
        }

        // Two fields cannot be mistaken for one — the procedure form is a single
        // key, so this stays a record
        #expect(throws: Never.self) {
            try sut.value(of: TypeExpression.record(["procedure": .int, "other": .bool]))
        }
    }

    @Test("what a document cannot say, a run does not see either")
    func whatIsRefusedNeverBecomesAnotherProgram() async throws {
        // Given — the refusals above are worth having only if the alternative is
        // worse. This is the alternative: the same shape written plainly comes
        // back as a comparison and answers, where the shape it came from is
        // refused before it runs.
        let asWritten: Value = [
            "procedures": [
                "entry": [
                    "parameters": ["word": "string"],
                    "body": [
                        [
                            "id": "pick",
                            "branch": [
                                "when": ["of": ["ref": "word"], "is": "hey"],
                                "then": ["result": "yes"],
                                "else": ["result": "no"]
                            ]
                        ]
                    ],
                    "result": ["result": ["ref": "pick"]]
                ]
            ]
        ]

        // When — read as a spelling, this is a comparison and it answers
        let outputs = try await run(
            try loader.load(asWritten),
            arguments: ["word": .string("hey")]
        )

        // Then
        #expect(outputs["result"] == .string("yes"))
    }

    // MARK: - Public
    // MARK: - Private
    // One statement around whatever is under test, since none of these shapes
    // can be reached by writing a document.
    private func module(binding expression: Warp.Expression) -> Module {
        Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["word": Parameter(type: .string)]),
                    body: [Statement(id: "probe", expression: expression)]
                )
            ]
        )
    }
}
