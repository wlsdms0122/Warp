//
//  VariableTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// Variables, asked of the language rather than of a notation. Nothing here
// spells `var:` or `set:` — those are how one front end writes a binding, and
// what is being tested is what a binding *is*.
@Suite
struct VariableTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a write inside a block outlives the block")
    func assignmentOutlivesItsBlock() async throws {
        // Given — the one thing a constant binding cannot do
        let sut: [Statement] = [
            Statement(id: "verdict", binding: .variable, expression: .literal(.string("untouched"))),
            Statement(
                id: "gate",
                expression: .conditional(
                    .literal(.bool(true)),
                    then: Block(body: [
                        Statement(
                            id: "verdict",
                            binding: .assignment,
                            expression: .literal(.string("touched"))
                        )
                    ]),
                    else: nil
                )
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("verdict"))

        // Then
        #expect(answer == .string("touched"))
    }

    @Test("a block that did not run writes nothing")
    func untakenBlockWritesNothing() async throws {
        // Given
        let sut: [Statement] = [
            Statement(id: "verdict", binding: .variable, expression: .literal(.string("untouched"))),
            Statement(
                id: "gate",
                expression: .conditional(
                    .literal(.bool(false)),
                    then: Block(body: [
                        Statement(
                            id: "verdict",
                            binding: .assignment,
                            expression: .literal(.string("touched"))
                        )
                    ]),
                    else: nil
                )
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("verdict"))

        // Then
        #expect(answer == .string("untouched"))
    }

    @Test("a variable declared inside a block does not escape it")
    func declarationDoesNotEscape() {
        // Given — the box is shared; which names exist is not
        let sut: [Statement] = [
            Statement(
                id: "gate",
                expression: .conditional(
                    .literal(.bool(true)),
                    then: Block(body: [
                        Statement(id: "inner", binding: .variable, expression: .literal(.int(1)))
                    ]),
                    else: nil
                )
            ),
            Statement(id: "read", expression: reference("inner"))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("a declaration inside a block shadows an outer variable instead of writing it")
    func declarationShadowsOuterVariable() async throws {
        // Given — a declaration always introduces, so the inner name has a box
        // of its own
        let sut: [Statement] = [
            Statement(id: "verdict", binding: .variable, expression: .literal(.string("outer"))),
            Statement(
                id: "gate",
                expression: .conditional(
                    .literal(.bool(true)),
                    then: Block(body: [
                        Statement(
                            id: "verdict",
                            binding: .variable,
                            expression: .literal(.string("inner"))
                        )
                    ]),
                    else: nil
                )
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("verdict"))

        // Then
        #expect(answer == .string("outer"))
    }

    @Test("a variable reads back what was last written to it")
    func variableReadsBackLastWrite() async throws {
        // Given
        let sut: [Statement] = [
            Statement(id: "tally", binding: .variable, expression: .literal(.int(1))),
            Statement(id: "tally", binding: .assignment, expression: .literal(.int(2))),
            Statement(id: "tally", binding: .assignment, expression: .literal(.int(3)))
        ]

        // When
        let answer = try await answer(of: sut, result: reference("tally"))

        // Then
        #expect(answer == .int(3))
    }

    @Test("an assignment sees the value it is replacing")
    func assignmentReadsItsOwnPriorValue() async throws {
        // Given — the expression is settled before the write lands, which is
        // what makes an accumulator work at all
        let sut: [Statement] = [
            Statement(id: "text", binding: .variable, expression: .literal(.string("a"))),
            Statement(
                id: "text",
                binding: .assignment,
                expression: interpolated(literal("<"), spelling(reference("text")), literal(">"))
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("text"))

        // Then
        #expect(answer == .string("<a>"))
    }

    @Test("writing a fixed name is refused")
    func writingConstantRefused() {
        // Given
        let sut: [Statement] = [
            Statement(id: "verdict", expression: .literal(.string("first"))),
            Statement(id: "verdict", binding: .assignment, expression: .literal(.string("second")))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("writing a name nothing declared is refused")
    func writingUndeclaredRefused() {
        // Given
        let sut = [
            Statement(id: "verdict", binding: .assignment, expression: .literal(.string("x")))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("a name reintroduced as a constant stops being writable")
    func constantReintroductionRevokesWriting() {
        // Given — shadowing runs both ways: an inner constant of the same name
        // is a different, fixed name, and the outer box is not reachable
        // through it
        let sut: [Statement] = [
            Statement(id: "verdict", binding: .variable, expression: .literal(.int(1))),
            Statement(
                id: "gate",
                expression: .block(
                    Block(body: [
                        Statement(id: "verdict", expression: .literal(.int(2))),
                        Statement(
                            id: "verdict",
                            binding: .assignment,
                            expression: .literal(.int(3))
                        )
                    ])
                )
            )
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("a closure may not write a variable from outside")
    func closureWriteOutwardRefused() {
        // Given — a closure may run beside another or long after this body, so
        // this is the ordering nothing can supply
        let sut: [Statement] = [
            Statement(id: "tally", binding: .variable, expression: .literal(.int(0))),
            Statement(
                id: "later",
                expression: .closure(
                    Procedure(
                        body: [
                            Statement(
                                id: "tally",
                                binding: .assignment,
                                expression: .literal(.int(1))
                            )
                        ],
                        result: reference("tally")
                    )
                )
            )
        ]

        // When / Then
        #expect(!validates(body: sut))
    }

    @Test("a closure owns the variables it declares")
    func closureOwnsItsVariables() async throws {
        // Given — what is refused is reaching outward, not variables
        let sut = [
            Statement(
                id: "both",
                expression: .dispatch(
                    Dispatch(
                        receiver: .record([
                            "left": .closure(
                                Procedure(
                                    body: [
                                        Statement(
                                            id: "tally",
                                            binding: .variable,
                                            expression: .literal(.int(0))
                                        ),
                                        Statement(
                                            id: "tally",
                                            binding: .assignment,
                                            expression: .literal(.int(1))
                                        )
                                    ],
                                    result: reference("tally")
                                )
                            ),
                            "right": .closure(Procedure(body: [], result: .literal(.int(2))))
                        ]),
                        selector: "all"
                    )
                )
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("both", "left"))

        // Then
        #expect(answer == .int(1))
    }

    @Test("what crosses loop rounds is the variable and nothing else")
    func loopCarriesOnlyVariables() async throws {
        // Given — the round writes a variable declared outside it and binds a
        // constant that must not survive the round
        let sut: [Statement] = [
            Statement(id: "latest", binding: .variable, expression: .literal(.int(0))),
            Statement(
                id: "gate",
                expression: .loop(
                    while: differs(reference("round", "index"), .literal(.int(3))),
                    body: Block(body: [
                        Statement(id: "transient", expression: reference("round", "index")),
                        Statement(id: "latest", binding: .assignment, expression: reference("transient"))
                    ]),
                    round: "round"
                )
            )
        ]

        // When
        let answer = try await answer(of: sut, result: reference("latest"))

        // Then — rounds 0/1/2 ran, and only `latest` came out
        #expect(answer == .int(2))
        #expect(!validates(body: sut + [Statement(id: "read", expression: reference("transient"))]))
    }
}
