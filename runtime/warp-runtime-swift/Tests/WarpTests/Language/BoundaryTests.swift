//
//  BoundaryTests.swift
//  WarpTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp

// What the standard vocabulary does at the edges.
//
// These are the cases that decide whether two implementations are the same
// language. Everyone agrees what one plus one is; the disagreements live in
// overflow, in division, and in what happens where a whole number meets a
// fraction — and an implementation that wraps where this one refuses is running
// programs this one would not.
//
// So they are written down in `spec/README.md`, and written here because prose
// ages against an implementation that keeps moving. Until the same cases can be
// run by an implementation that is not this one, this is the closest thing to a
// specification that cannot go stale.
@Suite("The standard vocabulary at its edges")
struct BoundaryTests {
    // MARK: - Property
    private let language = Language()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("what arithmetic takes is decided before it runs")
    func arithmeticIsCheckedBeforeRunning() throws {
        // Given — while arithmetic declared `any`, a sum of a number and a piece
        // of text was found by running it. In a language whose whole claim is
        // that what can be decided before running is, that was the claim not
        // holding in the most ordinary place a program has.
        let module = Module(
            procedures: [
                "entry": Procedure(
                    body: [],
                    result: .dispatch(
                        Dispatch(
                            receiver: .literal(.int(1)),
                            selector: "plus",
                            arguments: ["value": .literal(.string("a"))]
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect {
            try language.link([module] + Module.standard, entry: "entry")
        } throws: { error in
            "\(error)".contains("'N' is read as")
        }
    }

    @Test("what a word answers is what it was given, not merely a number")
    func arithmeticAnswersTheKindItWasGiven() throws {
        // Given — a whole number added to a whole number is a whole number, and
        // a declaration that only said "a number" would not fit anywhere asking
        // for one. Both sides and the answer are one reading, which is what a
        // language with overloading would need several declarations to say.
        let module = Module(
            procedures: [
                "entry": Procedure(
                    body: [],
                    result: .dispatch(
                        Dispatch(
                            selector: "wants",
                            arguments: [
                                "it": .dispatch(
                                    Dispatch(
                                        receiver: .literal(.int(1)),
                                        selector: "plus",
                                        arguments: ["value": .literal(.int(2))]
                                    )
                                )
                            ]
                        )
                    )
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: ["it": Parameter(type: .int)],
                        returns: .int
                    ),
                    body: [],
                    result: .reference([.key("it")])
                )
            ]
        )

        // When / Then
        #expect(throws: Never.self) {
            try language.link([module] + Module.standard, entry: "entry")
        }
    }

    @Test("ordering compares two of a kind, and text is a kind")
    func orderingIsNotOnlyForNumbers() async throws {
        // Given — the words that order values order text too, so declaring them
        // as taking numbers said something the word does not mean
        #expect(try await answering("lessThan", .string("a"), .string("b")) == .bool(true))
        #expect(try await answering("lessThan", .int(1), .int(2)) == .bool(true))
    }

    @Test("a slot that means either number takes either, and nothing else")
    func numberMeansBothAndOnlyBoth() {
        // Given — it is the numeric `any`, not a third kind of number. Nothing
        // is ever *of* it: a value is whole or it is a fraction.
        let sut = TypeExpression.number

        #expect(sut.accepts(.int))
        #expect(sut.accepts(.double))
        #expect(!sut.accepts(.string))
        #expect(!sut.accepts(.bool))

        // Where `any` would have taken those two as well, which is the whole
        // difference: one said nothing and this one said two things.
        #expect(TypeExpression.any.accepts(.string))

        // A value nothing said anything about still fits, here as everywhere —
        // refusing it would refuse every value no declaration had reached.
        #expect(sut.accepts(.any))
    }

    @Test("a hole read two ways that do not fit is a refusal, not a shrug")
    func aDisagreeingHoleIsRefused() {
        // Given — appending a whole number to a list of text. The hole is read
        // as text by the list and as a number by what is being appended, and
        // widening to `any` was the checker announcing it had stopped checking
        // and announcing it silently: the call then went through.
        let module = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(parameters: ["names": Parameter(type: .array(.string))]),
                    body: [],
                    result: .dispatch(
                        Dispatch(
                            receiver: .reference([.key("names")]),
                            selector: "appending",
                            arguments: ["value": .literal(.int(1))]
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect {
            try language.link([module] + Module.standard, entry: "entry")
        } throws: { error in
            "\(error)".contains("'Element' is read as")
                && "\(error)".contains("int")
                && "\(error)".contains("string")
        }
    }

    @Test("a hole read as anything is anything")
    func anyIsTheLoosestReading() throws {
        // Given — a list of anything, added to twice with two kinds of value.
        // `accepts` cannot order `any` against a shape, since everything takes
        // `any` and `any` takes everything, so asking which is looser answers
        // yes both ways and whichever was read first would win. Reading it first
        // is what a receiver does, and that made a list of anything into a list
        // of whatever went in first.
        let module = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(parameters: ["xs": Parameter(type: .array(.any))]),
                    body: [
                        Statement(
                            id: "one",
                            expression: .dispatch(
                                Dispatch(
                                    receiver: .reference([.key("xs")]),
                                    selector: "appending",
                                    arguments: ["value": .literal(.int(1))]
                                )
                            )
                        )
                    ],
                    result: .dispatch(
                        Dispatch(
                            receiver: .reference([.key("one")]),
                            selector: "appending",
                            arguments: ["value": .literal(.string("a"))]
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect(throws: Never.self) {
            try language.link([module] + Module.standard, entry: "entry")
        }
    }

    @Test("a name a module declared and the shape it stands for are one reading")
    func aDeclaredNameIsNotADisagreement() throws {
        // Given — the hole is read as `Tree` by the list and as the record the
        // call wrote. They are the same type, and calling them a disagreement
        // was asking the question without the table that answers it — the same
        // table the rest of the link uses.
        let module = Module(
            types: ["Tree": .record(["a": .int])],
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: ["trees": Parameter(type: .array(.named("Tree")))]
                    ),
                    body: [],
                    result: .dispatch(
                        Dispatch(
                            receiver: .reference([.key("trees")]),
                            selector: "appending",
                            arguments: ["value": .record(["a": .literal(.int(1))])]
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect(throws: Never.self) {
            try language.link([module] + Module.standard, entry: "entry")
        }
    }

    @Test("a hole read loosely and tightly holds the loose reading")
    func aWiderReadingHolds() throws {
        // Given — a list of numbers and a whole number are not a disagreement.
        // One reading takes the other, so the one that holds both is the answer,
        // and refusing here would refuse a program with nothing wrong with it.
        let module = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(parameters: ["counts": Parameter(type: .array(.number))]),
                    body: [],
                    result: .dispatch(
                        Dispatch(
                            receiver: .reference([.key("counts")]),
                            selector: "appending",
                            arguments: ["value": .literal(.int(1))]
                        )
                    )
                )
            ]
        )

        // When / Then
        #expect(throws: Never.self) {
            try language.link([module] + Module.standard, entry: "entry")
        }
    }

    @Test("whole-number arithmetic with no whole answer refuses")
    func wholeArithmeticRefusesRatherThanWraps() async throws {
        // Given — wrapping would answer, and answering wrongly is worse than
        // not answering. Widening silently would be worse still: the declared
        // type says whole, and a fraction is not one.
        for (word, left, right) in [
            ("plus", Int.max, 1),
            ("minus", Int.min, 1),
            ("times", Int.max, 2)
        ] {
            // When / Then
            await #expect {
                try await answering(word, .int(left), .int(right))
            } throws: { error in
                "\(error)".contains("no whole answer")
            }
        }
    }

    @Test("fraction arithmetic with no finite answer refuses")
    func fractionArithmeticRefusesRatherThanEscapes() async throws {
        // Given — the whole path already refuses what an int cannot hold, and
        // the fraction path could answer infinity: a value a program can carry
        // to exactly the first place that tries to write it down. Found by
        // running `1e308 plus 1e308` and being answered inf.
        for (word, left, right) in [
            ("plus", 1e308, 1e308),
            ("minus", -1e308, 1e308),
            ("times", 1e308, 10.0)
        ] {
            // When / Then
            await #expect {
                try await answering(word, .double(left), .double(right))
            } throws: { error in
                "\(error)".contains("no finite answer")
            }
        }
    }

    @Test("division answers a fraction, whole or not")
    func divisionAnswersAFraction() async throws {
        // Given — the alternative is two words, or one word whose answer type
        // depends on whether the division came out even. The second is not a
        // type a signature can hold.
        #expect(try await answering("dividedBy", .int(7), .int(2)) == .double(3.5))
        #expect(try await answering("dividedBy", .int(4), .int(2)) == .double(2))
    }

    @Test("division by zero refuses")
    func divisionByZeroRefuses() async throws {
        // Given — a fraction has an answer for this and it is not a number, so
        // answering with it would put something in a program that no later
        // check could talk about
        for (left, right) in [(Value.int(1), Value.int(0)), (.double(1), .double(0))] {
            await #expect {
                try await answering("dividedBy", left, right)
            } throws: { error in
                "\(error)".contains("zero")
            }
        }
    }

    @Test("a whole number widens to a fraction, and not the other way")
    func wholeNumbersWiden() async throws {
        // Given — every whole number is a fraction and the reverse is false, so
        // the conversion that cannot lose anything is the one that happens
        #expect(try await answering("plus", .int(1), .double(0.5)) == .double(1.5))
        #expect(try await answering("plus", .double(0.5), .int(1)) == .double(1.5))
    }

    // MARK: - Public
    // MARK: - Private
    // One word, sent to one value with one operand — the shape every arithmetic
    // word takes, so the cases above say what they are about and nothing else.
    private func answering(
        _ selector: String,
        _ receiver: Value,
        _ operand: Value
    ) async throws -> Value {
        let module = Module(
            procedures: [
                "entry": Procedure(
                    body: [],
                    result: .dispatch(
                        Dispatch(
                            receiver: .literal(receiver),
                            selector: selector,
                            arguments: ["value": .literal(operand)]
                        )
                    )
                )
            ]
        )

        return try await language
            .makeExecutor()
            .run(try language.link([module] + Module.standard, entry: "entry"))
    }
}
