//
//  ConcurrentTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// Running at once, as a document spells it: closures handed to the
// `std.concurrent` words. There is no construct here — a fan-out is a call,
// and what makes it safe is what a closure already is.
@Suite
struct ConcurrentTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("the environment's isolation boundary wraps every piece")
    func environmentIsolatesEachPiece() async throws {
        // Given
        let spec = try loader.loadProcedure([
            "body": [
                [
                    "id": "par",
                    "call": [
                        "procedure": "all",
                        "of": [
                            "left": ["closure": ["result": 1]],
                            "right": ["closure": ["result": 2]]
                        ]
                    ]
                ]
            ],
            "result": ["result": ["ref": "par"]]
        ])
        let boundary = IsolationBoundaryProbe()

        // When
        let outputs = try await run(spec, environment: boundary)

        // Then — every piece walked through the environment's isolation boundary
        #expect(boundary.isolatedCount == 2)
        #expect(outputs["result"] == .object(["left": .int(1), "right": .int(2)]))
    }

    @Test("all-recoverable failures rescue")
    func allRecoverableFailuresRescue() async throws {
        // Given
        let spec = try loader.loadProcedure([
            "body": [
                [
                    "id": "par",
                    "attempt": [
                        "body": [
                            [
                                "id": "par",
                                "call": [
                                    "procedure": "all",
                                    "of": [
                                        "fine": ["closure": ["result": "ok"]],
                                        "fragile": [
                                            "closure": [
                                                "body": [["id": "boom", "fail": true]],
                                                "result": ["ref": "boom"]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        "rescue": [
                            "body": [["id": "recovery", "value": "recovered"]],
                            "result": ["ref": "recovery"]
                        ]
                    ]
                ]
            ],
            "result": ["result": ["ref": "par"]]
        ])

        // When
        let outputs = try await run(spec)

        // Then
        #expect(outputs["result"] == .string("recovered"))
    }

    @Test("one piece's author mistake propagates the composite")
    func anyFatalPiecePropagates() async throws {
        // Given — one author mistake makes the composite an author mistake
        let spec = try loader.loadProcedure([
            "body": [
                [
                    "id": "par",
                    "attempt": [
                        "body": [
                            [
                                "id": "par",
                                "call": [
                                    "procedure": "all",
                                    "of": [
                                        "fragile": [
                                            "closure": [
                                                "body": [["id": "boom", "fail": true]],
                                                "result": ["ref": "boom"]
                                            ]
                                        ],
                                        "broken": [
                                            "closure": [
                                                "body": [["id": "boom", "fail": false]],
                                                "result": ["ref": "boom"]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        "rescue": ["body": [["id": "recovery", "value": "recovered"]]]
                    ]
                ]
            ]
        ])

        // When / Then
        await #expect(throws: TestFatalError.self) {
            try await run(spec)
        }
    }

    @Test("map walks a collection and answers in its order")
    func mapWalksACollection() async throws {
        // Given — the closure asks for the element under `item`, the same name
        // the sequential walk reads it by
        let sut = try loader.loadProcedure([
            "parameters": ["names": "array<string>"],
            "body": [
                [
                    "id": "greeted",
                    "call": [
                        "procedure": "std.concurrent.map",
                        "of": ["ref": "names"],
                        "arguments": [
                            "by": [
                                "closure": [
                                    "parameters": ["item": "string"],
                                    "body": [
                                        [
                                            "id": "line",
                                            "value": [
                                                "format": "hello, ${who}",
                                                "with": ["who": ["ref": "item"]]
                                            ]
                                        ]
                                    ],
                                    "result": ["ref": "line"]
                                ]
                            ]
                        ]
                    ]
                ]
            ],
            "result": ["result": ["ref": "greeted"]]
        ])

        // When
        let outputs = try await run(
            sut,
            arguments: ["names": .array([.string("a"), .string("b")])]
        )

        // Then
        #expect(outputs["result"] == .array([.string("hello, a"), .string("hello, b")]))
    }

    @Test("first answers whichever piece succeeds")
    func firstAnswersTheFirstSuccess() async throws {
        // Given
        let sut = try loader.loadProcedure([
            "body": [
                [
                    "id": "either",
                    "call": [
                        "procedure": "std.concurrent.first",
                        "of": [
                            [
                                "closure": [
                                    "body": [["id": "boom", "fail": true]],
                                    "result": ["ref": "boom"]
                                ]
                            ],
                            ["closure": ["result": "answered"]]
                        ]
                    ]
                ]
            ],
            "result": ["result": ["ref": "either"]]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .string("answered"))
    }
}

// Probe environment counting how many pieces pass through the isolation hook.
private final class IsolationBoundaryProbe: Environment, @unchecked Sendable {
    // MARK: - Property
    private let lock = NSLock()
    private var count = 0

    var isolatedCount: Int {
        lock.withLock { count }
    }

    // MARK: - Initializer
    // MARK: - Public
    func isolateConcurrentWork<T: Sendable>(
        _ work: @Sendable () async throws -> T
    ) async throws -> T {
        lock.withLock { count += 1 }

        return try await work()
    }

    // MARK: - Private
}
