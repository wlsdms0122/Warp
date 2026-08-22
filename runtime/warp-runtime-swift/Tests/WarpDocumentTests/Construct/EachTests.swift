//
//  EachTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

@Suite
struct EachTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a walk answers nothing, and its rounds write the flow they are in")
    func eachWritesOutwardAndAnswersNothing() async throws {
        // Given — a round's contribution is the write; rounds that answered
        // values would be a map, and the map words already say that
        let spec = try loader.loadProcedure([
            "parameters": ["items": "array"],
            "body": [
                ["var": "seen", "value": ""],
                [
                    "id": "walk",
                    "each": [
                        "in": ["ref": "items"],
                        "body": [
                            [
                                "set": "seen",
                                "value": [
                                    "format": "${so_far}${index}:${item}",
                                    "with": [
                                        "so_far": ["ref": "seen"],
                                        "index": ["ref": "walk.index"],
                                        "item": ["ref": "walk.item"]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            "result": ["seen": ["ref": "seen"]]
        ])

        // When
        let outputs = try await run(
            spec,
            arguments: ["items": .array([.string("a"), .string("b")])]
        )

        // Then
        #expect(outputs["seen"] == .string("0:a1:b"))
    }

    @Test("a result key on each is refused at decode")
    func aResultKeyIsRefusedAtDecode() throws {
        // Given — collecting rounds into an answer was `result`'s one job, and
        // that job is a map's; the key is gone rather than ignored
        #expect(throws: DecodingError.self) {
            try loader.loadProcedure([
                "parameters": ["items": "array"],
                "body": [
                    [
                        "id": "walk",
                        "each": [
                            "in": ["ref": "items"],
                            "body": [["id": "noop", "value": "x"]],
                            "result": ["ref": "noop"]
                        ]
                    ]
                ]
            ])
        }
    }

    @Test("walking non-array material is unfit")
    func nonArrayMaterialThrowsUnfit() async throws {
        // Given
        let spec = try loader.loadProcedure([
            "parameters": ["items": "string"],
            "body": [
                [
                    "id": "walk",
                    "each": ["in": ["ref": "items"], "body": [["id": "noop", "value": "x"]]]
                ]
            ]
        ])

        // When / Then
        await #expect(throws: ReferenceUnfit.self) {
            try await run(spec, arguments: ["items": .string("not-a-list")])
        }
    }

    @Test("with literal material the step id names the locus")
    func literalMaterialBlamesStepID() async throws {
        // Given — a literal `in` has no path to blame, so the step id carries it
        let spec = try loader.loadProcedure([
            "body": [
                [
                    "id": "walk",
                    "each": ["in": "not-a-list", "body": [["id": "noop", "value": "x"]]]
                ]
            ]
        ])

        // When / Then
        do {
            _ = try await run(spec)
            Issue.record("expected ExecutionError")
        } catch let error as ExecutionError {
            #expect(error.message.contains("walk"), "\(error)")
        }
    }
}
