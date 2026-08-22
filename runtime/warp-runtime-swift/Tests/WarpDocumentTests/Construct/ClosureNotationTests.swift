//
//  ClosureNotationTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// A capability the language has and the notation cannot spell is a capability
// only Swift has. These are the two words that close that gap.
@Suite("Writing a closure in a document")
struct ClosureNotationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("an author writes a construct that takes a body")
    func authorWrittenControlStructure() async throws {
        // Given — `twice` is a procedure, not a native word and not a language case
        let sut = try loader.load([
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "id": "ran",
                            "call": [
                                "procedure": "twice",
                                "arguments": [
                                    "body": [
                                        "closure": [
                                            "body": [["id": "said", "value": "hi"]],
                                            "result": ["ref": "said"]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ],
                    "result": ["result": ["ref": "ran"]]
                ],
                "twice": [
                    "parameters": ["body": "procedure"],
                    "body": [
                        ["id": "first", "invoke": ["procedure": ["ref": "body"]]],
                        ["id": "second", "invoke": ["procedure": ["ref": "body"]]]
                    ],
                    "result": ["said": [["ref": "first"], ["ref": "second"]]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(
            outputs["result"] == .object(["said": .array([.string("hi"), .string("hi")])])
        )
    }

    @Test("a closure reads what surrounded it, not what called it")
    func closureCapturesLexically() async throws {
        // Given
        let sut = try loader.load([
            "procedures": [
                "entry": [
                    "body": [
                        ["id": "outer", "value": "written"],
                        [
                            "id": "made",
                            "value": [
                                "closure": [
                                    "body": [["id": "seen", "value": ["ref": "outer"]]],
                                    "result": ["ref": "seen"]
                                ]
                            ]
                        ],
                        [
                            "id": "said",
                            "call": ["procedure": "runner", "arguments": ["body": ["ref": "made"]]]
                        ]
                    ],
                    "result": ["result": ["ref": "said"]]
                ],
                "runner": [
                    "parameters": ["body": "procedure"],
                    "body": [
                        ["id": "outer", "value": "called"],
                        ["id": "ran", "invoke": ["procedure": ["ref": "body"]]]
                    ],
                    "result": ["said": ["ref": "ran"]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .object(["said": .string("written")]))
    }

    @Test("a closure takes what it declares")
    func closureDeclaresParameters() async throws {
        // Given
        let sut = try loader.load([
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "id": "doubler",
                            "value": [
                                "closure": [
                                    "parameters": ["n": "int"],
                                    "body": [
                                        [
                                            "id": "out",
                                            "value": [
                                                "format": "n=${n}",
                                                "with": ["n": ["ref": "n"]]
                                            ]
                                        ]
                                    ],
                                    "result": ["ref": "out"]
                                ]
                            ]
                        ],
                        [
                            "id": "said",
                            "invoke": ["procedure": ["ref": "doubler"], "arguments": ["n": 3]]
                        ]
                    ],
                    "result": ["result": ["ref": "said"]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .string("n=3"))
    }

    @Test("a closure body is checked where it is written")
    func closureBodyIsValidated() {
        // Given
        let fixture: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "id": "made",
                            "value": [
                                "closure": ["body": [["id": "seen", "value": ["ref": "nowhere"]]]]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        // When / Then
        #expect(throws: (any Error).self) {
            try loader.load(fixture)
        }
    }

    @Test("a slot that declares what it wants refuses a closure that does not fit")
    func closureIsCheckedAgainstItsSlot() throws {
        // Given — `twice` says the body it takes answers a string, and the
        // closure written at the call site says it answers an int
        let fixture: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "id": "ran",
                            "call": [
                                "procedure": "twice",
                                "arguments": [
                                    "body": [
                                        "closure": [
                                            "returns": "int",
                                            "body": [["id": "said", "value": 1]]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ],
                "twice": [
                    "parameters": ["body": ["type": ["procedure": ["returns": "string"]]]],
                    "body": [["id": "first", "invoke": ["procedure": ["ref": "body"]]]]
                ]
            ]
        ]

        // When / Then
        #expect(throws: LinkError.self) {
            try loader.language.link(
                [try loader.load(fixture)] + Module.standard,
                entry: entryName
            )
        }
    }

    @Test("a closure that fits its slot links")
    func fittingClosureLinks() throws {
        // Given
        let fixture: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "id": "ran",
                            "call": [
                                "procedure": "twice",
                                "arguments": [
                                    "body": [
                                        "closure": [
                                            "returns": "string",
                                            "body": [["id": "said", "value": "hi"]]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ],
                "twice": [
                    "parameters": ["body": ["type": ["procedure": ["returns": "string"]]]],
                    "body": [["id": "first", "invoke": ["procedure": ["ref": "body"]]]]
                ]
            ]
        ]

        // When / Then
        _ = try loader.language.link(
            [try loader.load(fixture)] + Module.standard,
            entry: entryName
        )
    }
}
