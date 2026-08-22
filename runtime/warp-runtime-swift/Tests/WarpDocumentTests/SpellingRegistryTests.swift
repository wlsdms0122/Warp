//
//  SpellingRegistryTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// A notation can stop offering a spelling, and what that costs.
//
// The rule these are about is one sentence: **a notation may stop offering a
// spelling, and may not make the word mean something else.** Everything below is
// that read two ways — a document written plainly does not need the spellings at
// all, and a document that writes one nobody offered is refused rather than read
// as a record that happens to have those field names.
@Suite("A notation may stop offering a spelling")
struct SpellingRegistryTests {
    // MARK: - Property
    private let canonical = Loader(spellings: .canonical)

    // MARK: - Initializer
    // MARK: - Test
    @Test("giving up the spellings leaves nothing owed")
    func spellingNothingLeavesNothingOwed() throws {
        // Given — a canonical notation offers no spellings and registers no
        // construct that lowers to a word, so every shape it can still write is
        // one the language already has, and it owes no vocabulary at all. The
        // shipped spellings still owe what they stand in for.
        #expect(canonical.vocabulary.isEmpty)
        #expect(!Loader(spellings: .standard).vocabulary.isEmpty)
    }

    @Test("a spelling nobody reaches is not owed")
    func aSpellingNobodyReachesIsNotOwed() throws {
        // Given — the operator words are read through `when` and `where`, so a
        // notation offering every spelling and registering neither form spends
        // nothing on them. Offering is not spending.
        let sut = Loader(registry: try ConstructRegistry(forms: []), spellings: .standard)

        // Then
        #expect(sut.vocabulary.isDisjoint(with: SpellingRegistry.standard.operatorWords))
        #expect(sut.vocabulary == Spelling.interpolation)
    }

    @Test("dropping one spelling drops only what it reached")
    func droppingOneSpellingDropsOnlyItsWord() {
        // Given
        let sut = Loader(spellings: SpellingRegistry.standard.removing("one_of"))
        let word = try! #require(SpellingRegistry.standard.word(for: "one_of"))

        // Then — the word goes, and the ones still offered stay
        #expect(!sut.vocabulary.contains(word))
        #expect(sut.vocabulary.contains(try! #require(SpellingRegistry.standard.word(for: "is"))))
    }

    @Test("a canonical notation still writes every condition the language has")
    func canonicalConditionsAreWholeConditions() async throws {
        // Given — this is what makes the spellings a layer rather than a part of
        // the language. Nothing is lost by giving them up; the message the
        // spelling stood for is written out instead.
        let sut = try canonical.load([
            "procedures": [
                "entry": [
                    "parameters": ["word": "string"],
                    "body": [
                        [
                            "id": "pick",
                            "branch": [
                                "when": [
                                    "call": [
                                        "procedure": "std.logic.equal",
                                        "of": ["ref": "word"],
                                        "arguments": ["value": "hey"]
                                    ]
                                ],
                                "then": ["result": "matched"],
                                "else": ["result": "missed"]
                            ]
                        ]
                    ],
                    "result": ["result": ["ref": "pick"]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut, arguments: ["word": .string("hey")])

        // Then
        #expect(outputs["result"] == .string("matched"))
    }

    @Test("a spelling nobody offers is refused, not read as a record")
    func anUnofferedSpellingIsRefused() {
        // Given — the dangerous alternative. `{ of: …, is: … }` read as an
        // ordinary record would make the same document mean one thing here and
        // another in the notation next door, and nothing would say so.
        #expect {
            try canonical.load([
                "procedures": [
                    "entry": [
                        "parameters": ["word": "string"],
                        "body": [
                            [
                                "id": "pick",
                                "branch": [
                                    "when": ["of": ["ref": "word"], "is": "hey"],
                                    "then": ["result": "matched"]
                                ]
                            ]
                        ]
                    ]
                ]
            ])
        } throws: { error in
            "\(error)".contains("does not spell")
        }
    }

    @Test("a template nobody offers is refused, not read as a record")
    func anUnofferedTemplateIsRefused() {
        // Given — the same rule in the other slot
        #expect {
            try canonical.load([
                "procedures": [
                    "entry": [
                        "parameters": ["word": "string"],
                        "body": [
                            [
                                "id": "line",
                                "value": ["format": "${w}!", "with": ["w": ["ref": "word"]]]
                            ]
                        ]
                    ]
                ]
            ])
        } throws: { error in
            "\(error)".contains("does not spell a template")
        }
    }

    @Test("a word written as an operator is not a spelling and is untouched")
    func aCallersOwnOperatorIsNotASpelling() throws {
        // Given — `{ of: x, startsWith: "a" }` is `x` being sent `startsWith`.
        // That word was never this notation's to offer or drop, so a canonical
        // notation still reads it.
        let sut = try canonical.loadProcedure([
            "parameters": ["word": "string"],
            "body": [
                [
                    "id": "pick",
                    "branch": [
                        "when": ["of": ["ref": "word"], "startsWith": "a"],
                        "then": ["result": "yes"]
                    ]
                ]
            ]
        ])

        // Then
        guard
            case let .body(block) = sut.procedures[entryName]?.implementation,
            case let .conditional(condition, _, _) = block.body.first?.expression,
            case let .dispatch(dispatch) = condition
        else {
            Issue.record("an operator that is a word's own name is a message")

            return
        }

        #expect(dispatch.selector == "startsWith")
    }

    // MARK: - Public
    // MARK: - Private
}
