//
//  NamelessTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/22/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// A statement with no naming key: the construct runs and the answer is
// dropped, which is how an effect is asked for on its own. The other half of
// the same decision is that a leaving statement takes no name at all — it
// never finishes, so its name could never bind.
@Suite("A statement without a name")
struct NamelessTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a nameless statement runs and its answer is dropped")
    func aNamelessStatementRunsForItsEffect() async throws {
        // Given — a call whose answer nothing keeps, then an answer of its own
        let sut = try loader.load([
            "procedures": [
                "entry": [
                    "returns": "int",
                    "body": [
                        ["call": ["procedure": "plus", "of": 1, "arguments": ["value": 2]]],
                        ["id": "kept", "value": 5]
                    ],
                    "result": ["ref": "kept"]
                ]
            ]
        ])

        // When / Then
        #expect(try await answer(sut) == .int(5))
    }

    @Test("a nameless statement binds nothing a later statement could read")
    func aNamelessStatementBindsNothing() {
        // Given — the dropped answer is dropped, not bound under some
        // invented name a reference could reach; the reference resolves
        // nowhere and the reading says so
        #expect {
            try loader.load([
                "procedures": [
                    "entry": [
                        "body": [
                            ["value": 1]
                        ],
                        "result": ["ref": "_"]
                    ]
                ]
            ])
        } throws: { error in
            "\(error)".contains("not visible")
        }
    }

    @Test("two naming keys are refused")
    func twoNamingKeysAreRefused() {
        #expect(throws: DecodingError.self) {
            try loader.loadProcedure([
                "body": [["id": "one", "var": "another", "value": 1]]
            ])
        }
    }

    @Test("a named leaving statement is refused", arguments: [
        ["id": "done", "return": "answer"] as Value,
        ["var": "gone", "break": Value.null],
        ["set": "past", "continue": Value.null]
    ])
    func aNamedLeavingStatementIsRefused(_ statement: Value) {
        // Given — a leaving statement never finishes, so a naming key on one
        // promises a binding that cannot happen
        #expect {
            try loader.loadProcedure(["body": [statement]])
        } throws: { error in
            "\(error)".contains("takes no name")
        }
    }

    @Test("a construct that binds through its name cannot be written nameless", arguments: [
        ["loop": ["where": false, "body": [["id": "x", "value": 1]]]] as Value,
        ["each": ["in": ["value": [1]], "body": [["id": "x", "value": 1]]]],
        ["attempt": ["body": [["id": "x", "value": 1]], "rescue": ["result": 0]]]
    ])
    func aBindingConstructRequiresAName(_ statement: Value) {
        // Given — with no name there is nothing the body could read the
        // round/element/failure under, and an invented name would be a real
        // name somewhere
        #expect {
            try loader.loadProcedure(["body": [statement]])
        } throws: { error in
            "\(error)".contains("cannot be written nameless")
        }
    }

    @Test("a naming key holding null is a broken name, not a nameless statement")
    func aNullNameIsRefused() {
        // Given — a key written with no name in it: reading it as "no naming
        // key" would make a failed name and an omitted one the same document
        #expect(throws: DecodingError.self) {
            try loader.loadProcedure(["body": [["id": Value.null, "value": 1]]])
        }
    }

    @Test("a nameless statement written and read back is the same statement")
    func aNamelessStatementRoundTrips() throws {
        // Given — the reader's set of legal documents and the writer's must be
        // one set; a document that reads but does not write back broke that
        let document: Value = [
            "procedures": [
                "entry": [
                    "returns": "int",
                    "body": [
                        ["call": ["procedure": "plus", "of": 1, "arguments": ["value": 2]]],
                        ["id": "kept", "value": 5]
                    ],
                    "result": ["ref": "kept"]
                ]
            ]
        ]

        let loaded = try loader.load(document)
        let written = try Writer(registry: loader.registry).value(of: loaded)

        #expect(try Writer(registry: loader.registry).value(of: try loader.load(written)) == written)
    }

    @Test("a binding with no name is refused when statements are built directly")
    func aNamelessWriteIsRefusedFailLoud() {
        // Given — the document reader cannot produce this pair; a caller
        // assembling statements directly can, and silence would be a write
        // that goes nowhere
        let statement = Statement(binding: .assignment, expression: .literal(.int(1)))

        #expect {
            try Validator().validate(body: [statement], visible: [])
        } throws: { error in
            "\(error)".contains("writes no name")
        }
    }

    // MARK: - Public
    // MARK: - Private
    private func answer(_ module: Module, _ arguments: [String: Value] = [:]) async throws -> Value {
        let image = try loader.language.link([module] + Module.standard, entry: "entry")

        return try await loader.language.makeExecutor().run(image, arguments: arguments)
    }
}
