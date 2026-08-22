//
//  CanonicalTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// The document has two layers, and this suite is about the lower one: the shapes
// that stand one to one with the language, written without any spelling that
// stands in for a word.
//
// It matters because the lower layer is what travels. A program that leaves the
// machine it was written on arrives somewhere that has to read it, and every
// spelling is a rule that somewhere else has to implement the same way. The
// fewer of them the arriving side must understand, the smaller the promise.
@Suite("A document can be written without its spellings")
struct CanonicalTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a branch reads a condition written as a plain call")
    func branchReadsAPlainCondition() async throws {
        // Given — `{ of: x, is: 1 }` is one way to arrive at a condition. The
        // slot asks for an expression, and this is another.
        let sut = try loader.loadProcedure([
            "parameters": ["count": "int"],
            "body": [
                [
                    "id": "pick",
                    "branch": [
                        "when": [
                            "call": [
                                "procedure": "equal",
                                "of": ["ref": "count"],
                                "arguments": ["value": 1]
                            ]
                        ],
                        "then": ["result": "one"],
                        "else": ["result": "more"]
                    ]
                ]
            ],
            "result": ["result": ["ref": "pick"]]
        ])

        // When
        let one = try await run(sut, arguments: ["count": .int(1)])
        let more = try await run(sut, arguments: ["count": .int(2)])

        // Then
        #expect(one["result"] == .string("one"))
        #expect(more["result"] == .string("more"))
    }

    @Test("a loop reads a condition written as a plain call")
    func loopReadsAPlainCondition() async throws {
        // Given
        let sut = try loader.loadProcedure([
            "body": [
                ["var": "seen", "value": 0],
                [
                    "id": "walked",
                    "loop": [
                        "where": [
                            "call": [
                                "procedure": "notEqual",
                                "of": ["ref": "seen"],
                                "arguments": ["value": 3]
                            ]
                        ],
                        "body": [
                            [
                                "set": "seen",
                                "call": [
                                    "procedure": "plus",
                                    "of": ["ref": "seen"],
                                    "arguments": ["value": 1]
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            "result": ["result": ["ref": "seen"]]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .int(3))
    }

    @Test("a spelling and the call it stands for are the same program")
    func aSpellingMeansTheCallItStandsFor() async throws {
        // Given — the same question asked both ways. This is what makes the
        // spellings a layer rather than a part of the language: what they lower
        // to is writable, so nothing is only reachable by spelling it.
        func picking(on condition: Value) throws -> Module {
            try loader.loadProcedure([
                "parameters": ["word": "string"],
                "body": [
                    [
                        "id": "pick",
                        "branch": [
                            "when": condition,
                            "then": ["result": "matched"],
                            "else": ["result": "missed"]
                        ]
                    ]
                ],
                "result": ["result": ["ref": "pick"]]
            ])
        }

        let spelled = try picking(on: ["of": ["ref": "word"], "is": "hey"])
        let plainly = try picking(on: [
            "call": [
                "procedure": "equal",
                "of": ["ref": "word"],
                "arguments": ["value": "hey"]
            ]
        ])

        // When
        let hit = (
            try await run(spelled, arguments: ["word": .string("hey")]),
            try await run(plainly, arguments: ["word": .string("hey")])
        )
        let miss = (
            try await run(spelled, arguments: ["word": .string("ho")]),
            try await run(plainly, arguments: ["word": .string("ho")])
        )

        // Then
        #expect(hit.0 == hit.1)
        #expect(miss.0 == miss.1)
        #expect(hit.0["result"] == .string("matched"))
        #expect(miss.0["result"] == .string("missed"))
    }

    @Test("a condition that is simply a name is read as one")
    func aBareReferenceIsACondition() async throws {
        // Given — nothing about a condition says it must be a comparison. A
        // boolean already is one, and demanding it be spelled as `{ of: x,
        // is: true }` would be the notation making up a requirement.
        let sut = try loader.loadProcedure([
            "parameters": ["ready": "bool"],
            "body": [
                [
                    "id": "pick",
                    "branch": [
                        "when": ["ref": "ready"],
                        "then": ["result": "go"],
                        "else": ["result": "wait"]
                    ]
                ]
            ],
            "result": ["result": ["ref": "pick"]]
        ])

        // When
        let outputs = try await run(sut, arguments: ["ready": .bool(true)])

        // Then
        #expect(outputs["result"] == .string("go"))
    }

    // MARK: - Public
    // MARK: - Private
}
