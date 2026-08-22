//
//  ClosureTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// A procedure is a value. What that buys is not the case list — it is that an
// author can write the two things only Swift could write before: a construct
// that takes a body, and a procedure that makes one.
@Suite("A procedure is a value")
struct ClosureTests {
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a closure captures the scope it was written in, not the one it runs in")
    func closureCapturesLexically() async throws {
        // Given — `made` is written where `outer` says "written"; the call site
        // has an `outer` of its own saying something else
        let sut = [
            Statement(id: "outer", expression: .literal(.string("written"))),
            Statement(
                id: "made",
                expression: .closure(Procedure(body: [], result: reference("outer")))
            )
        ]

        // When
        let answer = try await answer(
            of: sut + [
                Statement(id: "shadow", expression: .literal(.string("called"))),
                Statement(
                    id: "said",
                    expression: .invoke(reference("made"), arguments: [:])
                )
            ],
            result: reference("said")
        )

        // Then
        #expect(answer == .string("written"))
    }

    @Test("a slot asking for a pure procedure refuses one that reaches outside")
    func anImpureClosureIsRefusedWherePurityIsAsked() throws {
        // Given — `twice` declares that whatever it is handed answers without
        // running. The closure handed to it shouts, and shouting is an effect
        let twice = Procedure(
            signature: Signature(
                parameters: ["body": Parameter(type: .procedure(nil, .pure))]
            ),
            body: [
                Statement(
                    id: "once",
                    expression: .invoke(reference("body"), arguments: [:])
                )
            ]
        )
        let sut = Module(
            procedures: [
                "twice": twice,
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "loud",
                            expression: .closure(
                                Procedure(
                                    body: [
                                        Statement(
                                            id: "said",
                                            expression: .dispatch(Dispatch(
                                                selector: "shout",
                                                arguments: ["text": .literal(.string("hi"))]
                                            ))
                                        )
                                    ],
                                    result: reference("said")
                                )
                            )
                        ),
                        Statement(
                            id: "ran",
                            expression: .dispatch(Dispatch(
                                selector: "twice",
                                arguments: ["body": reference("loud")]
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try Language().link([sut, .shouting] + Module.standard, entry: entryName)
        }
    }

    @Test("a slot asking for a pure procedure takes one that answers")
    func aPureClosureFitsWherePurityIsAsked() async throws {
        // Given — the same declaration, handed a body that only reads
        let twice = Procedure(
            signature: Signature(
                parameters: ["body": Parameter(type: .procedure(nil, .pure))],
                returns: .string
            ),
            body: [
                Statement(
                    id: "once",
                    expression: .invoke(reference("body"), arguments: [:])
                )
            ],
            result: reference("once")
        )
        let sut = Module(
            procedures: [
                "twice": twice,
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "quiet",
                            expression: .closure(
                                Procedure(body: [], result: .literal(.string("read")))
                            )
                        )
                    ],
                    result: .dispatch(Dispatch(
                        selector: "twice",
                        arguments: ["body": reference("quiet")]
                    ))
                )
            ]
        )

        // When
        let answer = try await run(sut)

        // Then
        #expect(answer == .string("read"))
    }

    @Test("an author can write a construct that takes a body")
    func authorWrittenControlStructure() async throws {
        // Given — `twice` is not a native word and not a language case. It is a
        // procedure that declares a procedure parameter and calls it, which is
        // the whole of what "the author can make constructs" means here.
        let twice = Procedure(
            signature: Signature(parameters: ["body": Parameter(type: .procedure(nil))]),
            body: [
                Statement(
                    id: "first",
                    expression: .invoke(reference("body"), arguments: [:])
                ),
                Statement(
                    id: "second",
                    expression: .invoke(reference("body"), arguments: [:])
                )
            ],
            result: .array([reference("first"), reference("second")])
        )

        // When
        let answer = try await answer(
            of: [
                Statement(
                    id: "ran",
                    expression: .dispatch(
                        Dispatch(
                            selector: "twice",
                            arguments: [
                                "body": .closure(
                                    Procedure(body: [], result: .literal(.string("hi")))
                                )
                            ]
                        )
                    )
                )
            ],
            result: reference("ran"),
            beside: ["twice": twice]
        )

        // Then
        #expect(answer == .array([.string("hi"), .string("hi")]))
    }

    @Test("a procedure can answer with a procedure")
    func procedureAnswersProcedure() async throws {
        // Given — the returned closure holds the argument its maker was given,
        // which is what makes returning one worth anything
        let makeGreeter = Procedure(
            signature: Signature(parameters: ["greeting": Parameter(type: .string)]),
            body: [],
            result: .closure(
                Procedure(
                    signature: Signature(parameters: ["name": Parameter(type: .string)]),
                    body: [],
                    result: interpolated(spelling(reference("greeting")), literal(", "), spelling(reference("name")))
                )
            )
        )

        // When
        let answer = try await answer(
            of: [
                Statement(
                    id: "hello",
                    expression: .dispatch(
                        Dispatch(
                            selector: "makeGreeter",
                            arguments: ["greeting": .literal(.string("hello"))]
                        )
                    )
                ),
                Statement(
                    id: "said",
                    expression: .invoke(
                        reference("hello"),
                        arguments: ["name": .literal(.string("warp"))]
                    )
                )
            ],
            result: reference("said"),
            beside: ["makeGreeter": makeGreeter]
        )

        // Then
        #expect(answer == .string("hello, warp"))
    }

    @Test("closures travel in arrays and records like any other value")
    func closuresTravelInStructures() async throws {
        // Given
        let sut = [
            Statement(
                id: "table",
                expression: .record([
                    "yes": .closure(Procedure(body: [], result: .literal(.string("y")))),
                    "no": .closure(Procedure(body: [], result: .literal(.string("n"))))
                ])
            ),
            Statement(
                id: "picked",
                expression: .invoke(reference("table", "yes"), arguments: [:])
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("picked"))

        // Then
        #expect(answer == .string("y"))
    }

    @Test("calling something that is not a procedure fails with what it was")
    func callingNonProcedureFails() async {
        // Given
        let sut = [
            Statement(id: "notCallable", expression: .literal(.int(1))),
            Statement(
                id: "called",
                expression: .invoke(reference("notCallable"), arguments: [:])
            )
        ]

        // When / Then
        await #expect(throws: ExecutionError.self) {
            try await answer(of: sut, result: reference("called"))
        }
    }

    @Test("a closure body is validated where it is written")
    func closureBodyIsValidatedAtItsSite() {
        // Given — the body may read what surrounds the literal and what the
        // literal declares, and nothing else
        let readsEnclosing = Warp.Expression.closure(
            Procedure(body: [], result: reference("outer"))
        )
        let readsItsOwn = Warp.Expression.closure(
            Procedure(
                signature: Signature(parameters: ["mine": Parameter(type: .int)]),
                body: [],
                result: reference("mine")
            )
        )
        let readsNothingReal = Warp.Expression.closure(
            Procedure(body: [], result: reference("nowhere"))
        )

        // Then
        #expect(validates(readsEnclosing, visible: ["outer"]))
        #expect(!validates(readsEnclosing))
        #expect(validates(readsItsOwn))
        #expect(!validates(readsNothingReal))
    }

    @Test("a procedure is never equal to a procedure")
    func proceduresHaveNoEquality() {
        // Given — there is no honest answer, so the language does not offer one
        let sut = Value.procedure(
            Closure(procedure: Procedure(body: []), captured: Scope())
        )

        // Then
        #expect(sut != sut)
        #expect(sut.type == .procedure)
    }
}
