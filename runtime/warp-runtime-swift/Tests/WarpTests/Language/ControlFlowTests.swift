//
//  ControlFlowTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// Control flow is a closed set of expression cases the language owns, so each
// one is asked here directly — what it answers with, and what its body can see.
@Suite
struct ControlFlowTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a block answers what it says it answers, and nothing if it says nothing")
    func aBlockAnswersOnlyWhatItDeclares() async throws {
        // Given — reading the last statement instead would put the answer in the
        // ordering, where nothing points at it. Appending a statement would
        // change what the block was worth, and the author who appended it wrote
        // nothing that says so.
        let sut = Warp.Expression.block(
            Block(body: [
                Statement(id: "first", expression: .literal(.int(1))),
                Statement(id: "second", expression: .literal(.int(2)))
            ])
        )

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .null)
    }

    @Test("a declared result outranks the last statement")
    func declaredResultOutranksLastStatement() async throws {
        // Given
        let sut = Warp.Expression.block(
            Block(
                body: [
                    Statement(id: "first", expression: .literal(.int(1))),
                    Statement(id: "second", expression: .literal(.int(2)))
                ],
                result: reference("first")
            )
        )

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .int(1))
    }

    @Test("what a block binds does not escape it")
    func blockBindingsDoNotEscape() {
        // Given
        let sut: [Statement] = [
            Statement(
                id: "probe",
                expression: .block(
                    Block(body: [Statement(id: "inner", expression: .literal(.int(1)))])
                )
            ),
            Statement(id: "read", expression: reference("inner"))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("a conditional answers with the arm it took")
    func conditionalAnswersWithTakenArm() async throws {
        // Given
        let sut = { (take: Bool) in
            Warp.Expression.conditional(
                .literal(.bool(take)),
                then: Block(
                    body: [Statement(id: "yes", expression: .literal(.string("then")))],
                    result: .reference([.key("yes")])
                ),
                else: Block(
                    body: [Statement(id: "no", expression: .literal(.string("else")))],
                    result: .reference([.key("no")])
                )
            )
        }

        // When
        let taken = try await answer(
            of: [Statement(id: "probe", expression: sut(true))],
            result: reference("probe")
        )
        let untaken = try await answer(
            of: [Statement(id: "probe", expression: sut(false))],
            result: reference("probe")
        )

        // Then
        #expect(taken == .string("then"))
        #expect(untaken == .string("else"))
    }

    @Test("a declining conditional without an else answers null")
    func decliningConditionalAnswersNull() async throws {
        // Given — a skipped statement binds null, which is absence as a value
        // rather than a name that does not exist
        let sut = Warp.Expression.conditional(
            .literal(.bool(false)),
            then: Block(body: [Statement(id: "yes", expression: .literal(.string("then")))]),
            else: nil
        )

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .null)
    }

    @Test("a loop reads how many rounds have passed")
    func loopReadsItsRoundIndex() async throws {
        // Given
        let sut = Warp.Expression.loop(
            while: differs(reference("round", "index"), .literal(.int(3))),
            body: Block(body: [Statement(id: "tick", expression: reference("round", "index"))]),
            round: "round"
        )

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then — the loop answers null without a declared result, and the
        // round state is the loop's own: it is not visible after it
        #expect(answer == .null)
        #expect(
            !validates(
                body: [
                    Statement(id: "probe", expression: sut),
                    Statement(id: "rounds", expression: reference("round", "index"))
                ]
            )
        )
    }

    @Test("an author bounds a loop with the language it already has")
    func anAuthorBoundsALoopWithACounterAndAbort() async throws {
        // Given — repetition carries no budget of its own; a counter in the
        // condition and `abort` past the bound say it exactly, and the failure
        // is a word's failure like any other
        let sut = Warp.Expression.loop(
            while: .dispatch(
                Dispatch(
                    receiver: reference("round", "index"),
                    selector: "lessThan",
                    arguments: ["value": .literal(.int(3))]
                )
            ),
            body: Block(body: [
                Statement(
                    expression: .conditional(
                        .dispatch(
                            Dispatch(
                                receiver: reference("round", "index"),
                                selector: "equal",
                                arguments: ["value": .literal(.int(2))]
                            )
                        ),
                        then: Block(body: [
                            Statement(
                                expression: .dispatch(
                                    Dispatch(
                                        receiver: .literal(.string("too many rounds")),
                                        selector: "abort"
                                    )
                                )
                            )
                        ]),
                        else: nil
                    )
                )
            ]),
            round: "round"
        )

        // When / Then
        await #expect(throws: Aborted.self) {
            try await answer(
                of: [Statement(id: "probe", expression: sut)],
                result: reference("probe")
            )
        }
    }

    @Test("a walk answers nothing, and what its rounds wrote outward stays written")
    func iterationAnswersNothingAndItsWritesRemain() async throws {
        // Given — a round's contribution is the write; a walk whose rounds
        // answered values would be a map, and `std.collection.map` is that
        let sut = Warp.Expression.iteration(
            over: .array([.literal(.int(1)), .literal(.int(2)), .literal(.int(3))]),
            body: [
                Statement(
                    id: "sum",
                    binding: .assignment,
                    expression: .dispatch(
                        Dispatch(
                            receiver: reference("sum"),
                            selector: "plus",
                            arguments: ["value": reference("element", "item")]
                        )
                    )
                )
            ],
            element: "element"
        )

        // When
        let answer = try await answer(
            of: [
                Statement(id: "sum", binding: .variable, expression: .literal(.int(0))),
                Statement(id: "walk", expression: sut)
            ],
            result: reference("sum")
        )

        // Then
        #expect(answer == .int(6))
    }

    @Test("a walk's name is the element's, and is not readable after the walk")
    func aWalkNameIsNotVisibleAfterTheWalk() {
        // Given — the walk answers nothing, so a later read of its name could
        // only ever see null. Refused at the check rather than answered silently.
        #expect(!validates(body: [
            Statement(
                id: "walk",
                expression: .iteration(
                    over: .array([.literal(.int(1))]),
                    body: [],
                    element: "walk"
                )
            ),
            Statement(id: "read", expression: reference("walk"))
        ]))
    }

    @Test("iteration over something that is not an array is unfit")
    func iterationOverNonArrayIsUnfit() async throws {
        // Given
        let sut = Warp.Expression.iteration(
            over: reference("material"),
            body: [],
            element: "element"
        )

        // When / Then
        await #expect(throws: ReferenceUnfit.self) {
            try await answer(
                of: [Statement(id: "probe", expression: sut)],
                result: .literal(.null),
                arguments: ["material": .string("not an array")],
                signature: Signature(parameters: ["material": Parameter(type: .string)])
            )
        }
    }

    @Test("a rescue runs on a recoverable failure and can read it")
    func rescueRunsAndReadsTheFailure() async throws {
        // Given
        let sut = Warp.Expression.attempt(
            Block(body: [
                Statement(
                    id: "boom",
                    expression: .dispatch(
                        Dispatch(
                            selector: "fail",
                            arguments: ["recoverable": .literal(.bool(true))]
                        )
                    )
                )
            ]),
            rescue: Block(body: [], result: reference("failure", "message")),
            failure: "failure"
        )

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe"),
            vocabulary: Module.standard + [.failing]
        )

        // Then
        #expect(answer == .string("the world did not cooperate"))
    }

    @Test("an author mistake passes through a rescue")
    func authorMistakeIsNotRescued() async throws {
        // Given — recovery is for a world that did not cooperate, not for a
        // procedure that is wrong
        let sut = Warp.Expression.attempt(
            Block(body: [
                Statement(
                    id: "boom",
                    expression: .dispatch(
                        Dispatch(
                            selector: "fail",
                            arguments: ["recoverable": .literal(.bool(false))]
                        )
                    )
                )
            ]),
            rescue: Block(body: [], result: .literal(.string("recovered"))),
            failure: "failure"
        )

        // When / Then
        await #expect(throws: TestFatalError.self) {
            try await answer(
                of: [Statement(id: "probe", expression: sut)],
                result: reference("probe"),
                vocabulary: Module.standard + [.failing]
            )
        }
    }

    @Test("an empty rescue is refused")
    func emptyRescueRefused() {
        // Given — a rescue that produces nothing swallows a failure into null
        // without a trace
        let sut = Warp.Expression.attempt(
            Block(body: [Statement(id: "work", expression: .literal(.int(1)))]),
            rescue: Block(body: []),
            failure: "failure"
        )

        // When / Then
        #expect(!validates(sut))
    }
}
