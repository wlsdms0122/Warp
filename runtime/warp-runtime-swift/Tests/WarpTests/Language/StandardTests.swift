//
//  StandardTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// The words that ship in bundles, and the fact that they are bundles: a caller
// takes the ones its programs have use for, and a name from a bundle it left out
// does not resolve.
@Suite("The standard vocabulary")
struct StandardTests {
    // MARK: - Property
    private let language = Language()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a bundle left out is a bundle whose names do not resolve")
    func aBundleLeftOutDoesNotResolve() throws {
        // Given — a program that only counts, linked without the bundle that
        // declares counting
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "many",
                            expression: .dispatch(Dispatch(
                                receiver: .literal(.array([.int(1)])),
                                selector: "count"
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut, .math, .text], entry: entryName)
        }

        #expect(throws: Never.self) {
            try language.link([sut, .collection], entry: entryName)
        }
    }

    @Test("a connective leaves the rest unasked once the answer is settled")
    func connectivesShortCircuit() async throws {
        // Given — the later side divides by zero, which refuses when it is
        // asked. `all` is settled by the first false, so it never is
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "verdict",
                            expression: every(
                                equals(.literal(.int(1)), .literal(.int(2))),
                                equals(
                                    .dispatch(Dispatch(
                                        receiver: .literal(.int(1)),
                                        selector: "dividedBy",
                                        arguments: ["value": .literal(.int(0))]
                                    )),
                                    .literal(.int(0))
                                )
                            )
                        )
                    ],
                    result: reference("verdict")
                )
            ]
        )

        // When / Then
        #expect(try await run(sut) == .bool(false))
    }

    @Test("a word takes a procedure the author wrote and runs it")
    func aWalkTakesAProcedure() async throws {
        // Given — map, filter and reduce are declarations rather than
        // constructs. Nothing in the grammar knows they exist
        let doubling = Procedure(
            signature: Signature(parameters: ["item": Parameter(type: .int)], returns: .int),
            body: [],
            result: .dispatch(Dispatch(
                receiver: reference("item"),
                selector: "times",
                arguments: ["value": .literal(.int(2))]
            ))
        )
        let odd = Procedure(
            signature: Signature(parameters: ["item": Parameter(type: .int)], returns: .bool),
            body: [
                Statement(
                    id: "left",
                    expression: .dispatch(Dispatch(
                        receiver: reference("item"),
                        selector: "remainder",
                        arguments: ["value": .literal(.int(2))]
                    ))
                )
            ],
            result: equals(reference("left"), .literal(.int(1)))
        )
        let adding = Procedure(
            signature: Signature(
                parameters: [
                    "carried": Parameter(type: .int),
                    "item": Parameter(type: .int)
                ],
                returns: .int
            ),
            body: [],
            result: .dispatch(Dispatch(
                receiver: reference("carried"),
                selector: "plus",
                arguments: ["value": reference("item")]
            ))
        )

        let sut = Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["ns": Parameter(type: .array(.int))]),
                    body: [
                        Statement(
                            id: "doubled",
                            expression: .dispatch(Dispatch(
                                receiver: reference("ns"),
                                selector: "std.collection.map",
                                arguments: ["value": .closure(doubling)]
                            ))
                        ),
                        Statement(
                            id: "kept",
                            expression: .dispatch(Dispatch(
                                receiver: reference("ns"),
                                selector: "filter",
                                arguments: ["value": .closure(odd)]
                            ))
                        ),
                        Statement(
                            id: "total",
                            expression: .dispatch(Dispatch(
                                receiver: reference("ns"),
                                selector: "reduce",
                                arguments: [
                                    "from": .literal(.int(0)),
                                    "value": .closure(adding)
                                ]
                            ))
                        )
                    ],
                    result: .record([
                        "doubled": reference("doubled"),
                        "kept": reference("kept"),
                        "total": reference("total")
                    ])
                )
            ]
        )

        // When
        let answer = try await run(
            sut,
            arguments: ["ns": .array([.int(1), .int(2), .int(3)])]
        )

        // Then
        #expect(
            answer == .object([
                "doubled": .array([.int(2), .int(4), .int(6)]),
                "kept": .array([.int(1), .int(3)]),
                "total": .int(6)
            ])
        )
    }

    @Test("a walk declares what it hands over, and a body reads what it wants")
    func aWalkOffersRatherThanRequires() async throws {
        // Given — `reduce` hands over `carried` and `item`. Counting only needs
        // the first, and declaring the second to leave it unread would be a
        // declaration the author never meant
        let counting = Procedure(
            signature: Signature(
                parameters: ["carried": Parameter(type: .int)],
                returns: .int
            ),
            body: [],
            result: .dispatch(Dispatch(
                receiver: reference("carried"),
                selector: "plus",
                arguments: ["value": .literal(.int(1))]
            ))
        )
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["ns": Parameter(type: .array(.int))]),
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: reference("ns"),
                        selector: "reduce",
                        arguments: [
                            "from": .literal(.int(0)),
                            "value": .closure(counting)
                        ]
                    ))
                )
            ]
        )

        // When
        let answer = try await run(
            sut,
            arguments: ["ns": .array([.int(7), .int(8), .int(9)])]
        )

        // Then
        #expect(answer == .int(3))
    }

    @Test("a walk refuses a procedure that reaches outside")
    func aWalkRefusesAnImpureProcedure() throws {
        // Given — `map` declares `pure procedure`, so a body that shouts is
        // refused before any run rather than suspending inside a path
        let loud = Procedure(
            signature: Signature(parameters: ["item": Parameter(type: .string)]),
            body: [],
            result: .dispatch(Dispatch(
                selector: "shout",
                arguments: ["text": reference("item")]
            ))
        )
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["names": Parameter(type: .array(.string))]),
                    body: [],
                    result: .dispatch(Dispatch(
                        receiver: reference("names"),
                        selector: "std.collection.map",
                        arguments: ["value": .closure(loud)]
                    ))
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut, .shouting] + Module.standard, entry: entryName)
        }
    }

    @Test("whole arithmetic with no answer refuses rather than taking the process")
    func wholeArithmeticRefusesWhatItCannotAnswer() async throws {
        // Given — every one of these is a Swift trap if the answer is taken
        // rather than judged, and each arrives at run time
        let asks: [(String, Value, Value)] = [
            ("remainder", .int(5), .int(0)),
            ("dividedBy", .int(5), .int(0)),
            ("times", .int(Int.max), .int(2)),
            ("plus", .int(Int.max), .int(1)),
            ("minus", .int(Int.min), .int(1))
        ]

        for (word, receiver, operand) in asks {
            let sut = Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .dispatch(Dispatch(
                            receiver: .literal(receiver),
                            selector: word,
                            arguments: ["value": .literal(operand)]
                        ))
                    )
                ]
            )

            // When / Then
            await #expect(throws: ExecutionError.self, "\(word) took the process") {
                try await run(sut)
            }
        }
    }

    @Test("a double with no whole answer refuses rather than taking the process")
    func roundingRefusesWhatAnIntCannotHold() async throws {
        // Given
        let asks: [(String, Value)] = [
            ("floored", .double(1e30)),
            ("rounded", .double(1e30)),
            ("absolute", .int(Int.min))
        ]

        for (word, receiver) in asks {
            let sut = Module(
                procedures: [
                    entryName: Procedure(
                        body: [],
                        result: .dispatch(Dispatch(
                            receiver: .literal(receiver),
                            selector: word
                        ))
                    )
                ]
            )

            // When / Then
            await #expect(throws: ExecutionError.self, "\(word) took the process") {
                try await run(sut)
            }
        }
    }

    @Test("a whole division reads both halves")
    func wholeDivisionIsWritable() async throws {
        // Given — `dividedBy` always answers a double, so a whole division is
        // that floored, and what it left over is `remainder`
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["n": Parameter(type: .int)]),
                    body: [
                        Statement(
                            id: "quotient",
                            expression: .dispatch(Dispatch(
                                receiver: reference("n"),
                                selector: "dividedBy",
                                arguments: ["value": .literal(.int(4))]
                            ))
                        ),
                        Statement(
                            id: "whole",
                            expression: .dispatch(Dispatch(
                                receiver: reference("quotient"),
                                selector: "floored"
                            ))
                        ),
                        Statement(
                            id: "left",
                            expression: .dispatch(Dispatch(
                                receiver: reference("n"),
                                selector: "remainder",
                                arguments: ["value": .literal(.int(4))]
                            ))
                        )
                    ],
                    result: .record([
                        "left": reference("left"),
                        "whole": reference("whole")
                    ])
                )
            ]
        )

        // When
        let answer = try await run(sut, arguments: ["n": .int(11)])

        // Then
        #expect(answer == .object(["whole": .int(2), "left": .int(3)]))
    }

    @Test("an array grows and shrinks, which is a length the text did not write")
    func anArrayIsBuiltRatherThanSpelled() async throws {
        // Given — a body walking a grid: the head moves and wraps, the trail
        // takes it on and lets its own end go. Nothing here is a length the
        // author could have counted, and `each` cannot write it because `each`
        // answers one element for every element it was given.
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(
                        parameters: [
                            "trail": Parameter(type: .array(.int)),
                            "head": Parameter(type: .int),
                            "side": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "stepped",
                            expression: .dispatch(Dispatch(
                                receiver: reference("head"),
                                selector: "plus",
                                arguments: ["value": .literal(.int(1))]
                            ))
                        ),
                        Statement(
                            id: "wrapped",
                            expression: .dispatch(Dispatch(
                                receiver: reference("stepped"),
                                selector: "remainder",
                                arguments: ["value": reference("side")]
                            ))
                        ),
                        Statement(
                            id: "grown",
                            expression: .dispatch(Dispatch(
                                receiver: reference("trail"),
                                selector: "prepending",
                                arguments: ["value": reference("wrapped")]
                            ))
                        ),
                        Statement(
                            id: "moved",
                            expression: .dispatch(Dispatch(
                                receiver: reference("grown"),
                                selector: "dropLast"
                            ))
                        )
                    ],
                    result: .record([
                        "grown": reference("grown"),
                        "moved": reference("moved")
                    ])
                )
            ]
        )

        // When — the head sits at the last column, so stepping wraps it to 0
        let answer = try await run(
            sut,
            arguments: [
                "head": .int(3),
                "side": .int(4),
                "trail": .array([.int(3), .int(2), .int(1)])
            ]
        )

        // Then
        #expect(
            answer == .object([
                "grown": .array([.int(0), .int(3), .int(2), .int(1)]),
                "moved": .array([.int(0), .int(3), .int(2)])
            ])
        )
    }

    @Test("an object is walked and rebuilt without naming its fields")
    func anObjectIsDataRatherThanAShape() async throws {
        // Given
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["counts": Parameter(type: .object(.int))]),
                    body: [
                        Statement(
                            id: "named",
                            expression: .dispatch(Dispatch(
                                receiver: reference("counts"),
                                selector: "keys"
                            ))
                        ),
                        Statement(
                            id: "held",
                            expression: .dispatch(Dispatch(
                                receiver: reference("counts"),
                                selector: "values"
                            ))
                        ),
                        Statement(
                            id: "changed",
                            expression: .dispatch(Dispatch(
                                receiver: reference("counts"),
                                selector: "setting",
                                arguments: [
                                    "key": .literal(.string("b")),
                                    "value": .literal(.int(9))
                                ]
                            ))
                        )
                    ],
                    result: .record([
                        "changed": reference("changed"),
                        "held": reference("held"),
                        "named": reference("named")
                    ])
                )
            ]
        )

        // When
        let answer = try await run(
            sut,
            arguments: ["counts": .object(["a": .int(1), "b": .int(2)])]
        )

        // Then
        #expect(
            answer == .object([
                "named": .array([.string("a"), .string("b")]),
                "held": .array([.int(1), .int(2)]),
                "changed": .object(["a": .int(1), "b": .int(9)])
            ])
        )
    }

    @Test("whole numbers stay whole, and a quotient does not")
    func arithmeticKeepsItsRepresentation() async throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "sum",
                            expression: .dispatch(Dispatch(selector: "plus", arguments: [
                                        "of": .literal(.int(2)),
                                        "value": .literal(.int(3))
                                    ]))
                        ),
                        Statement(
                            id: "product",
                            expression: .dispatch(Dispatch(selector: "times", arguments: [
                                        "of": .literal(.int(4)),
                                        "value": .literal(.double(2.5))
                                    ]))
                        ),
                        Statement(
                            id: "quotient",
                            expression: .dispatch(Dispatch(selector: "dividedBy", arguments: [
                                        "of": .literal(.int(7)),
                                        "value": .literal(.int(2))
                                    ]))
                        )
                    ],
                    result: .record([
                            "product": .reference([.key("product")]),
                            "quotient": .reference([.key("quotient")]),
                            "sum": .reference([.key("sum")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["sum"] == .int(5))
        #expect(outputs["product"] == .double(10))
        #expect(outputs["quotient"] == .double(3.5))
    }

    @Test("dividing by zero is refused rather than answered")
    func divisionByZeroFails() async throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "gone",
                            expression: .dispatch(Dispatch(selector: "dividedBy", arguments: [
                                        "of": .literal(.int(1)),
                                        "value": .literal(.int(0))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        await #expect(throws: ExecutionError.self) {
            try await run(sut)
        }
    }

    @Test("ordering reads as a condition, which is what it was missing")
    func comparisonReadsAsACondition() async throws {
        // Given — `{ of: x, lessThan: y }` is the condition grammar sending a
        // word, so ordering needed no grammar of its own
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "n": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "verdict",
                            expression: .conditional(.dispatch(Dispatch(receiver: .reference([.key("n")]), selector: "lessThan", arguments: [
                                            "value": .literal(.int(10))
                                        ])), then: Block(body: [
                                        Statement(
                                            id: "small",
                                            expression: .literal(.string("small"))
                                        )
                                    ], result: .reference([.key("small")])), else: Block(body: [
                                        Statement(
                                            id: "large",
                                            expression: .literal(.string("large"))
                                        )
                                    ], result: .reference([.key("large")])))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("verdict")])
                        ])
                )
            ]
        )

        // When / Then
        #expect(try await run(sut, arguments: ["n": .int(3)])["result"] == .string("small"))
        #expect(try await run(sut, arguments: ["n": .int(30)])["result"] == .string("large"))
    }

    @Test("a word that needs nothing is reachable from a path")
    func nilaryWordsAreReachableFromPaths() async throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "items": Parameter(type: .array(.string)),
                            "name": Parameter(type: .string)
                        ]
                    ),
                    body: [],
                    result: .record([
                            "back": .reference([.key("items"), .key("reversed")]),
                            "head": .reference([.key("items"), .key("first")]),
                            "loud": .reference([.key("name"), .key("uppercased")]),
                            "tail": .reference([.key("items"), .key("last")]),
                            "together": .reference([.key("items"), .key("joined")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(
            sut,
            arguments: [
                "name": .string("warp"),
                "items": .array([.string("a"), .string("b")])
            ]
        )

        // Then
        #expect(outputs["loud"] == .string("WARP"))
        #expect(outputs["head"] == .string("a"))
        #expect(outputs["tail"] == .string("b"))
        #expect(outputs["back"] == .array([.string("b"), .string("a")]))
        #expect(outputs["together"] == .string("ab"))
    }

    @Test("text words compose the way a document writes them")
    func textWordsCompose() async throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "line": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "parts",
                            expression: .dispatch(Dispatch(selector: "split", arguments: [
                                        "of": .reference([.key("line")]),
                                        "value": .literal(.string(","))
                                    ]))
                        ),
                        Statement(
                            id: "rejoined",
                            expression: .dispatch(Dispatch(selector: "joined", arguments: [
                                        "of": .reference([.key("parts")]),
                                        "value": .literal(.string(" / "))
                                    ]))
                        ),
                        Statement(
                            id: "fixed",
                            expression: .dispatch(Dispatch(selector: "replacing", arguments: [
                                        "of": .reference([.key("rejoined")]),
                                        "value": .literal(.string("b")),
                                        "with": .literal(.string("B"))
                                    ]))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("fixed")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(sut, arguments: ["line": .string("a,b,c")])

        // Then
        #expect(outputs["result"] == .string("a / B / c"))
    }

    @Test("what a word answers is declared, so the link reads it")
    func standardAnswersAreDeclared() throws {
        // Given — `count` declares that it answers an int, and `split` declares
        // that it is sent a string
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "items": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "many",
                            expression: .dispatch(Dispatch(selector: "count", arguments: [
                                        "of": .reference([.key("items")])
                                    ]))
                        ),
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "split", arguments: [
                                        "of": .reference([.key("many")]),
                                        "value": .literal(.string(","))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("bytes do not order")
    func bytesDoNotOrder() async throws {
        // Given — bytes are an opaque value: equal or not, counted, and
        // nothing else. An order would imply a reading, and bytes are the kind
        // that has none.
        let sut = Warp.Expression.dispatch(
            Dispatch(
                receiver: .literal(.bytes([0x01])),
                selector: "lessThan",
                arguments: ["value": .literal(.bytes([0x02]))]
            )
        )

        // When / Then
        await #expect {
            try await answer(of: [Statement(id: "probe", expression: sut)], result: reference("probe"))
        } throws: { error in
            "\(error)".contains("two numbers or two strings")
        }
    }

    @Test("a walk hands a null element over as the element it is")
    func aWalkCarriesNullElements() async throws {
        // Given — `map` offers each element to the procedure it was given, and
        // an element that is null was still an element of the collection
        let sut = Warp.Expression.dispatch(
            Dispatch(
                receiver: .literal(.array([.int(1), .null])),
                selector: "std.collection.map",
                arguments: [
                    "value": .closure(
                        Procedure(
                            signature: Signature(
                                parameters: ["item": Parameter(type: .any)]
                            ),
                            body: [],
                            result: reference("item")
                        )
                    )
                ]
            )
        )

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .array([.int(1), .null]))
    }

    @Test("two spellings of one text are one value")
    func stringsCompareAsAPersonReads() async throws {
        // Given — Unicode writes `é` two ways, and the two are different bytes.
        // A name is held to one spelling (normal form C), but a string value
        // arrives from the world spelled however the world spelled it — so
        // equality reads the text the way a person does, not the bytes.
        let sut = Warp.Expression.dispatch(
            Dispatch(
                receiver: .literal(.string("caf\u{E9}")),
                selector: "equal",
                arguments: ["value": .literal(.string("cafe\u{301}"))]
            )
        )

        // When
        let answer = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answer == .bool(true))
    }

    // MARK: - Control

    @Test("abort refuses carrying its rendered message")
    func abortRefusesWithItsMessage() async throws {
        // Given
        let sut = refusing(interpolated(literal("no: "), spelling(reference("reason"))))

        // When / Then — nameless and last, with no result: nothing may be
        // written after what never finishes, so the procedure ends with it
        await #expect {
            try await run(
                Procedure(
                    signature: Signature(parameters: ["reason": Parameter(type: .string)]),
                    body: [Statement(expression: sut)]
                ),
                arguments: ["reason": .string("out of room")]
            )
        } throws: { error in
            (error as? Aborted)?.message == "no: out of room"
        }
    }

    @Test("a refusal is caught by an attempt around it")
    func abortIsRecoverable() async throws {
        // Given — `RecoverableFailure` is what separates the world refusing from
        // the author being wrong, and a refusal is the first kind
        let sut = Warp.Expression.attempt(
            Block(body: [Statement(expression: refusing(literal("stopped")))]),
            rescue: Block(body: [], result: .literal(.string("caught"))),
            failure: "failure"
        )

        // When
        let answered = try await answer(
            of: [Statement(id: "probe", expression: sut)],
            result: reference("probe")
        )

        // Then
        #expect(answered == .string("caught"))
    }

    @Test("an arm that refuses does not decide what the arm that stays holds")
    func refusalDoesNotWidenTheOtherArm() throws {
        // Given — `returns: never` is what keeps the branch a string. Were it
        // `any`, the consumer below would be allowed to disagree with it.
        let sut = Module(
            name: "app",
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["ok": Parameter(type: .bool)]),
                    body: [
                        Statement(
                            id: "either",
                            expression: .conditional(
                                reference("ok"),
                                then: Block(body: [], result: .literal(.string("here"))),
                                else: Block(body: [], result: refusing(literal("gone")))
                            )
                        ),
                        Statement(
                            id: "used",
                            expression: .dispatch(
                                Dispatch(selector: "wants", arguments: ["it": reference("either")])
                            )
                        )
                    ],
                ),
                "wants": Procedure(
                    signature: Signature(parameters: ["it": Parameter(type: .int)]),
                    body: []
                )
            ]
        )

        // When / Then — the branch holds a string, and `wants` declares an int
        #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }
    }
}
