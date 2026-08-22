//
//  DispatchTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// A procedure, a library word and a caller reaching outside are one expression, and
// the only difference is where the selector was found. These ask the language
// that directly, without a notation in between to spell the three differently.
@Suite
struct DispatchTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a library word, a native word and a procedure are sent the same way")
    func threeKindsOfWordAreOneExpression() async throws {
        // Given
                let echo = Procedure(
            signature: Signature(parameters: ["text": Parameter(type: .string)]),
            body: [],
            result: .record(["said": reference("text")])
        )
        let sut: [Statement] = [
            Statement(
                id: "counted",
                expression: .dispatch(
                    Dispatch(receiver: .array([.literal(.int(1)), .literal(.int(2))]), selector: "count")
                )
            ),
            Statement(
                id: "shouted",
                expression: .dispatch(
                    Dispatch(selector: "shout", arguments: ["text": .literal(.string("hi"))])
                )
            ),
            Statement(
                id: "echoed",
                expression: .dispatch(
                    Dispatch(selector: "echo", arguments: ["text": .literal(.string("back"))])
                )
            )
        ]

        // When
        let outputs = try await run(
            Procedure(
                body: sut,
                result: .record([
                    "counted": reference("counted"),
                    "shouted": reference("shouted"),
                    "echoed": reference("echoed", "said")
                ])
            ),
            beside: ["echo": echo],
            vocabulary: Module.standard + [.shouting]
        )

        // Then
        #expect(outputs["counted"] == .int(2))
        #expect(outputs["shouted"] == .string("HI"))
        #expect(outputs["echoed"] == .string("back"))
    }

    @Test("a word that declines the shape it was sent to reads as absence")
    func decliningWordReadsAsAbsence() async throws {
        // Given — `count` has nothing to say about an int, and a word saying
        // nothing is the same answer as a field nobody set
        let sut = Warp.Expression.dispatch(
            Dispatch(receiver: .literal(.int(7)), selector: "count")
        )

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .null)
    }

    @Test("a trailing path segment that names no field is a send")
    func trailingSegmentIsASend() async throws {
        // Given — `${items.count}` is `obj.count`: the front end cannot know
        // whether the last segment is a field or a word, so it does not decide
        let sut = Warp.Expression.reference([.key("items"), .key("count")])

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe"),
            arguments: ["items": .array([.int(1), .int(2), .int(3)])],
            signature: Signature(parameters: ["items": Parameter(type: .array(.any))])
        )

        // Then
        #expect(answer == .int(3))
    }

    @Test("two declarations of one qualified name are refused at link")
    func oneNameIsDeclaredOnce() throws {
        // Given / When / Then — which one runs must never be a link-order
        // accident, and an implementation is not a namespace: a body and a
        // native answering one name collide the same way two bodies would
        let rival = Module(
            name: "std.collection",
            procedures: [
                "count": Procedure(
                    signature: Signature(returns: .int),
                    implementation: .effect(ShoutEffect())
                )
            ]
        )

        #expect(throws: LinkError.self) {
            try Language().link(
                [Module(procedures: ["entry": Procedure(body: [])]), rival] + Module.standard,
                entry: "entry"
            )
        }
    }

    @Test("a native word is linked against its signature like a procedure is")
    func hostWordIsCheckedAgainstItsSignature() async throws {
        // Given — an argument the word does not declare. This was unreachable
        // while an effect was an opaque Swift value.
        let sut = Procedure(
            body: [
                Statement(
                    id: "shouted",
                    expression: .dispatch(
                        Dispatch(
                            selector: "shout",
                            arguments: [
                                "text": .literal(.string("hi")),
                                "volume": .literal(.int(11))
                            ]
                        )
                    )
                )
            ]
        )

        // When / Then
        await #expect(throws: LinkError.self) {
            try await run(sut, vocabulary: Module.standard + [.shouting])
        }
    }

    @Test("a required argument nobody passed is refused before the run")
    func missingRequiredArgumentRefused() async throws {
        // Given
        let sut = Procedure(
            body: [
                Statement(
                    id: "shouted",
                    expression: .dispatch(Dispatch(selector: "shout"))
                )
            ]
        )

        // When / Then
        await #expect(throws: LinkError.self) {
            try await run(sut, vocabulary: Module.standard + [.shouting])
        }
    }

    @Test("a constant argument of the wrong type is refused before the run")
    func constantArgumentTypeRefused() async throws {
        // Given — only arguments that already are what they will be can be
        // judged here, and a constant is one
        let sut = Procedure(
            body: [
                Statement(
                    id: "shouted",
                    expression: .dispatch(
                        Dispatch(selector: "shout", arguments: ["text": .literal(.int(7))])
                    )
                )
            ]
        )

        // When / Then
        await #expect(throws: LinkError.self) {
            try await run(sut, vocabulary: Module.standard + [.shouting])
        }
    }

    @Test("a selector nothing answers is refused before the run")
    func unresolvedSelectorRefused() async throws {
        // Given — a self-contained procedure that calls something should be told
        // it had nowhere to look, rather than handed an empty answer
        let sut = Procedure(
            body: [Statement(id: "gone", expression: .dispatch(Dispatch(selector: "nowhere")))]
        )

        // When / Then
        await #expect(throws: LinkError.self) {
            try await run(sut)
        }
    }

    @Test("a typo in an arm today's arguments never take is still refused")
    func unreachedArmIsStillLinked() async throws {
        // Given — the warrant is compilation, not loading: a run with expensive
        // effects should not discover a typo halfway through
        let sut = Procedure(
            body: [
                Statement(
                    id: "gate",
                    expression: .conditional(
                        .literal(.bool(false)),
                        then: Block(body: [
                            Statement(
                                id: "gone",
                                expression: .dispatch(Dispatch(selector: "nowhere"))
                            )
                        ]),
                        else: nil
                    )
                )
            ]
        )

        // When / Then
        await #expect(throws: LinkError.self) {
            try await run(sut)
        }
    }

    @Test("a procedure calling itself links once instead of forever")
    func recursiveProcedureLinksOnce() async throws {
        // Given
        let countdown = Procedure(
                signature: Signature(parameters: ["n": Parameter(type: .int)]),
                body: [
                    Statement(
                        id: "again",
                        expression: .conditional(
                            differs(reference("n"), .literal(.int(0))),
                            then: Block(body: [
                                Statement(
                                    id: "recur",
                                    expression: .dispatch(
                                        Dispatch(
                                            selector: "countdown",
                                            arguments: ["n": .literal(.int(0))]
                                        )
                                    )
                                )
                            ]),
                            else: nil
                        )
                    )
                ],
            result: .record(["done": .literal(.bool(true))])
        )
        let sut = Procedure(
            body: [
                Statement(
                    id: "run",
                    expression: .dispatch(
                        Dispatch(selector: "countdown", arguments: ["n": .literal(.int(1))])
                    )
                )
            ],
            result: .record(["done": reference("run", "done")])
        )

        // When
        let outputs = try await run(sut, beside: ["countdown": countdown])

        // Then
        #expect(outputs["done"] == .bool(true))
    }
}

// MARK: - Support



