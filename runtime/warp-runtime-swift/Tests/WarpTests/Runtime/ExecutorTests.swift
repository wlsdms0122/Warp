//
//  ExecutorTests.swift
//  WarpTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp

@Suite
struct ExecutorTests {
    // MARK: - Property
    private let language = Language()

    // MARK: - Initializer
    // MARK: - Test
    @Test("bindings flow through a step sequence")
    func bindingsFlowThroughSequence() async throws {
        // Given
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "who": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "greeting",
                            expression: interpolated(literal("hello, "), spelling(reference("who")))
                        ),
                        Statement(
                            id: "loud",
                            expression: interpolated(spelling(reference("greeting")), literal("!"))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("loud")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(spec, arguments: ["who": .string("spec")])

        // Then
        #expect(outputs["result"] == .string("hello, spec!"))
    }

    @Test("a declining condition skips the step and binds null")
    func decliningConditionSkipsStep() async throws {
        // Given
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "kind": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "only-a",
                            expression: .conditional(equals(
                                        .reference([.key("kind")]),
                                        .literal(.string("a"))
                                        ), then: Block(body: [
                                        Statement(
                                            id: "taken",
                                            expression: .literal(.string("taken"))
                                        )
                                    ]), else: nil)
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("only-a")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(spec, arguments: ["kind": .string("b")])

        // Then — a skipped step binds null, not absence
        #expect(outputs["result"] == .null)
    }

    @Test("a recoverable failure runs the rescue path")
    func recoverableFailureRunsRescue() async throws {
        // Given
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "fragile",
                            expression: .attempt(Block(body: [
                                        Statement(
                                            id: "fragile",
                                            expression: .dispatch(Dispatch(selector: "fail", arguments: [
                                                        "recoverable": .literal(.bool(true))
                                                    ]))
                                        )
                                    ]), rescue: Block(
                                        body: [
                                            Statement(
                                                id: "recovery",
                                                expression: .literal(.string("recovered"))
                                            )
                                        ],
                                        result: .reference([.key("recovery")])
                                    ), failure: "fragile")
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("fragile")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(spec, vocabulary: Module.standard + [.failing])

        // Then — the last rescue step's output becomes the step output
        #expect(outputs["result"] == .string("recovered"))
    }

    @Test("the failure is a value inside the rescue, and only there")
    func rescueSeesFailurePayload() async throws {
        // Given
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "fragile",
                            expression: .attempt(Block(body: [
                                        Statement(
                                            id: "fragile",
                                            expression: .dispatch(Dispatch(selector: "fail", arguments: [
                                                        "recoverable": .literal(.bool(true))
                                                    ]))
                                        )
                                    ]), rescue: Block(
                                        body: [
                                            Statement(
                                                id: "reason",
                                                expression: interpolated(
                                                    literal("saw: "),
                                                    spelling(reference("fragile", "message"))
                                                )
                                            )
                                        ],
                                        result: .reference([.key("reason")])
                                    ), failure: "fragile")
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("fragile")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(spec, vocabulary: Module.standard + [.failing])

        // Then — inside the rescue, `fragile` was the failure payload; after
        // it, `fragile` is the rescue's output (a string here), so the payload
        // never leaks past the rescue
        #expect(outputs["result"] == .string("saw: the world did not cooperate"))
    }

    @Test("an author mistake propagates past rescue")
    func fatalErrorBypassesRescue() async throws {
        // Given — an author mistake must not be absorbed by rescue
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "broken",
                            expression: .attempt(Block(body: [
                                        Statement(
                                            id: "broken",
                                            expression: .dispatch(Dispatch(selector: "fail", arguments: [
                                                        "recoverable": .literal(.bool(false))
                                                    ]))
                                        )
                                    ]), rescue: Block(body: [
                                        Statement(
                                            id: "recovery",
                                            expression: .literal(.string("recovered"))
                                        )
                                    ]), failure: "broken")
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: TestFatalError.self) {
            try await run(spec, vocabulary: Module.standard + [.failing])
        }
    }

    @Test("an unrescued failure propagates")
    func unrescuedFailurePropagates() async throws {
        // Given
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "fragile",
                            expression: .dispatch(Dispatch(selector: "fail", arguments: [
                                        "recoverable": .literal(.bool(true))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: TestRecoverableFailure.self) {
            try await run(spec, vocabulary: Module.standard + [.failing])
        }
    }

    @Test("a reference typo is not disguised by rescue")
    func referenceTypoBypassesRescue() async throws {
        // Given — shape misuse is an author error; rescue must not disguise it
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "n": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "fragile",
                            expression: .attempt(Block(body: [
                                        Statement(
                                            id: "fragile",
                                            expression: interpolated(
                                                literal("x="),
                                                spelling(reference("n", "field"))
                                            )
                                        )
                                    ]), rescue: Block(body: [
                                        Statement(
                                            id: "recovery",
                                            expression: .literal(.string("recovered"))
                                        )
                                    ]), failure: "fragile")
                        )
                    ]
                )
            ]
        )

        // When / Then — a rescue cannot disguise what the link already refused,
        // because there is no run for it to be part of
        await #expect(throws: LinkError.self) {
            try await run(spec, arguments: ["n": .int(1)])
        }
    }

    @Test("a field the data does not carry reads as null, and does not fail")
    func absentFieldReadsAsNull() async throws {
        // Given — absence is optionality, not a failure: nothing is thrown, so
        // the rescue never runs
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "data": Parameter(type: .object(.any))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "fragile",
                            expression: .attempt(Block(body: [
                                        Statement(
                                            id: "fragile",
                                            expression: .reference([.key("data"), .key("missing")])
                                        )
                                    ]), rescue: Block(body: [
                                        Statement(
                                            id: "recovery",
                                            expression: .literal(.string("recovered"))
                                        )
                                    ]), failure: "fragile")
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("fragile")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(spec, arguments: ["data": .object([:])])

        // Then
        #expect(outputs["result"] == .null)
    }

    @Test("interpolating a null stays an author mistake, and rescue does not absorb it")
    func nullInsideTemplateIsAuthorMistake() async throws {
        // Given — a skipped step binds null; reading it is fine, writing it
        // into text is not, and an author mistake passes through rescue
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "kind": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "maybe",
                            expression: .conditional(equals(
                                        .reference([.key("kind")]),
                                        .literal(.string("a"))
                                        ), then: Block(body: [
                                        Statement(
                                            id: "made",
                                            expression: .record([
                                                    "name": .literal(.string("made"))
                                                ])
                                        )
                                    ]), else: nil)
                        ),
                        Statement(
                            id: "fragile",
                            expression: .attempt(Block(body: [
                                        Statement(
                                            id: "fragile",
                                            expression: interpolated(
                                                literal("name="),
                                                spelling(reference("maybe", "name"))
                                            )
                                        )
                                    ]), rescue: Block(body: [
                                        Statement(
                                            id: "recovery",
                                            expression: .literal(.string("recovered"))
                                        )
                                    ]), failure: "fragile")
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("fragile")])
                        ])
                )
            ]
        )

        // When
        // When / Then
        await #expect(throws: ReferenceUnfit.self) {
            try await run(spec, arguments: ["kind": .string("b")])
        }
    }

    @Test("abort throws carrying its rendered message")
    func abortThrowsWithMessage() async throws {
        // Given
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "reason": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        // Nameless on purpose — a statement that never finishes
                        // binds nothing, so a name on it is refused at link.
                        Statement(
                            expression: refusing(interpolated(
                                        literal("stopped: "),
                                        spelling(reference("reason"))
                                    ))
                        )
                    ]
                )
            ]
        )

        // When / Then — abort is the language's throw, and carries its message
        do {
            _ = try await run(spec, arguments: ["reason": .string("no data")])
            Issue.record("expected Aborted")
        } catch let aborted as Aborted {
            #expect(aborted.message == "stopped: no data")
        }
    }

    @Test("abort is caught by rescue like any thrown error")
    func abortRescuesLikeThrownError() async throws {
        // Given — like a thrown error, abort is catchable
        let spec = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "bail",
                            expression: .attempt(Block(body: [
                                        Statement(
                                            expression: refusing(literal("giving up"))
                                        )
                                    ]), rescue: Block(
                                        body: [
                                            Statement(
                                                id: "recovery",
                                                expression: .literal(.string("recovered"))
                                            )
                                        ],
                                        result: .reference([.key("recovery")])
                                    ), failure: "bail")
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("bail")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(spec)

        // Then
        #expect(outputs["result"] == .string("recovered"))
    }
}
