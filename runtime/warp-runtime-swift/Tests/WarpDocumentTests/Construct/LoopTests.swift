//
//  LoopTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

@Suite
struct LoopTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("loop repeats while its where holds")
    func loopRepeatsWhileConditionHolds() async throws {
        // Given — the loop writes a variable declared outside it and reads its
        // own round index through ${gate.index}
        let spec = try loader.loadProcedure([
            "body": [
                ["var": "latest", "value": 0],
                [
                    "id": "gate",
                    "loop": [
                        "where": ["of": ["ref": "gate.index"], "is_not": 3],
                        "body": [["set": "latest", "value": ["ref": "gate.index"]]],
                        "result": ["ref": "latest"]
                    ]
                ]
            ],
            "result": ["result": ["ref": "gate"]]
        ])

        // When
        let outputs = try await run(spec)

        // Then — rounds 0/1/2 ran; at index 3 the where turned false
        #expect(outputs["result"] == .int(2))
    }

    @Test("a loop runs unbounded, like while")
    func loopRunsUnbounded() async throws {
        // Given — the language carries no budget; the world (here, the
        // condition) ends the repetition
        let spec = try loader.loadProcedure([
            "body": [
                ["var": "latest", "value": 0],
                [
                    "id": "gate",
                    "loop": [
                        "where": ["of": ["ref": "gate.index"], "is_not": 7],
                        "body": [["set": "latest", "value": ["ref": "gate.index"]]],
                        "result": ["ref": "latest"]
                    ]
                ]
            ],
            "result": ["result": ["ref": "gate"]]
        ])

        // When
        let outputs = try await run(spec)

        // Then
        #expect(outputs["result"] == .int(6))
    }

    @Test("a guard key on loop is refused at decode")
    func aGuardKeyIsRefusedAtDecode() throws {
        // Given — repetition carries no budget of its own: an author bounds a
        // loop with a counter and a word, and a receiver stops one with
        // cancellation. The key is gone rather than ignored.
        #expect(throws: DecodingError.self) {
            try loader.loadProcedure([
                "body": [
                    [
                        "id": "gate",
                        "loop": [
                            "where": ["of": ["ref": "gate.index"], "is_not": 3],
                            "body": [["id": "noop", "value": "again"]],
                            "guard": 2
                        ]
                    ]
                ]
            ])
        }
    }

    @Test("an empty-body loop still observes cancellation")
    func emptyBodyObservesCancellation() async throws {
        // Given — an empty body must still observe cancellation, or the caller's
        // one lever against a runaway loop stops working
        let spec = try loader.loadProcedure([
            "body": [
                [
                    "id": "gate",
                    "loop": ["where": ["present": ["ref": "gate.index"]], "body": []]
                ]
            ]
        ])

        // When
        let task = Task {
            try await run(spec)
        }

        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        // Then
        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }

    @Test("a loop body may rebind an outer id by shadowing")
    func loopRebindsOuterIDByShadowing() throws {
        // Given — the retry-loop idiom rebinds an outer id inside loop steps
        let fixture: Value = [
            "body": [
                ["id": "format", "value": "first"],
                [
                    "id": "gate",
                    "loop": [
                        "where": ["of": ["ref": "gate.index"], "is": 0],
                        "body": [["id": "format", "value": "retried"]],
                    ]
                ]
            ]
        ]

        // When / Then
        #expect(throws: Never.self) {
            try loader.loadProcedure(fixture)
        }
    }
}
