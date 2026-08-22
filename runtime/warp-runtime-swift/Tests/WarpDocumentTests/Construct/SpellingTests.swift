//
//  SpellingTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// A construct's word belongs to the table, not to the type that reads it. The
// language's constructs are anonymous, so nothing downstream of the registry can
// tell which word arrived — and these are the facts that follow.
@Suite("A word belongs to the registry")
struct SpellingTests {
    // MARK: - Property
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a form can be registered under another word")
    func formTakesTheRegistrysWord() async throws {
        // Given — `unless` is `branch` spelled differently, and the IR it builds
        // cannot say which of the two was written
        let loader = Loader(
            registry: try ConstructRegistry.standard.registering(
                BranchForm.self,
                as: "unless"
            ),
            spellings: .standard
        )
        let sut = try loader.loadProcedure([
            "parameters": ["kind": "string"],
            "body": [
                [
                    "id": "pick",
                    "unless": [
                        "when": ["of": ["ref": "kind"], "is": "a"],
                        "then": [
                            "body": [["id": "chosen", "value": "took-then"]],
                            "result": ["ref": "chosen"]
                        ],
                        "else": [
                            "body": [["id": "chosen", "value": "took-else"]],
                            "result": ["ref": "chosen"]
                        ]
                    ]
                ]
            ],
            "result": ["result": ["ref": "pick"]]
        ])

        // When
        let outputs = try await run(sut, arguments: ["kind": .string("a")])

        // Then
        #expect(outputs["result"] == .string("took-then"))
    }

    @Test("registering a form twice is an alias, so both words work")
    func aliasKeepsBothWords() throws {
        // Given / When
        let sut = try ConstructRegistry.standard.registering(BranchForm.self, as: "unless")

        // Then
        #expect(sut.form(for: "branch") != nil)
        #expect(sut.form(for: "unless") != nil)
    }

    @Test("a word can be given up, and a built-in respelled by giving it up first")
    func removingFreesTheWord() throws {
        // Given — a notation that wants `invoke` for something of its own takes
        // it by dropping ours, which is why a rename here is not a rename of the
        // language
        let sut = try ConstructRegistry.standard
            .removing("invoke")
            .registering(InvokeForm.self, as: "apply")

        // Then
        #expect(sut.form(for: "invoke") == nil)
        #expect(sut.form(for: "apply") != nil)
    }

    @Test("a claimed word is never silently replaced, however it was claimed")
    func claimedWordRejected() throws {
        // Given
        let sut = try ConstructRegistry.standard.registering(BranchForm.self, as: "unless")

        // When / Then — the guard is on the word, not on the form
        #expect(throws: ValidationError.self) {
            try sut.registering(LoopForm.self, as: "unless")
        }
    }

    @Test("a word the registry does not hold is not a construct")
    func unregisteredWordRefused() {
        // Given — `branch` given up is `branch` unspellable
        let loader = Loader(registry: ConstructRegistry.standard.removing("branch"))

        // When / Then
        #expect(throws: (any Error).self) {
            try loader.loadProcedure([
                "parameters": ["kind": "string"],
                "body": [
                    [
                        "id": "pick",
                        "branch": [
                            "when": ["of": ["ref": "kind"], "is": "a"],
                            "then": [
                                "body": [["id": "chosen", "value": "took-then"]],
                                "result": ["ref": "chosen"]
                            ]
                        ]
                    ]
                ]
            ])
        }
    }
}
