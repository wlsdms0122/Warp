//
//  InferenceTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// An author binds a call to a name and passes the name, so a declared answer
// only reaches the next call site if the link knows what that name holds. These
// are the places knowing it turns two declarations into a refusal before
// anything runs.
@Suite("What the link knows a name holds")
struct InferenceTests {
    // MARK: - Property
    private let language = Language()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a hole carries the element type through the call that filled it")
    func aHoleCarriesWhatFilledIt() throws {
        // Given — `first` takes `array<some Element>` and answers `some Element`,
        // so what it answers here is a string and the declaration never said so
        let wants = Procedure(
            signature: Signature(parameters: ["word": Parameter(type: .string)]),
            body: []
        )
        let sut = Module(
            procedures: [
                "wants": wants,
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["names": Parameter(type: .array(.string))]
                    ),
                    body: [
                        Statement(
                            id: "head",
                            expression: .dispatch(Dispatch(
                                receiver: reference("names"),
                                selector: "std.collection.first"
                            ))
                        ),
                        Statement(
                            id: "asked",
                            expression: .dispatch(Dispatch(
                                selector: "wants",
                                arguments: ["word": reference("head")]
                            ))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: Never.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a hole filled with one shape refuses a call wanting another")
    func aFilledHoleRefusesWhatDisagrees() throws {
        // Given — the same walk, over an array of ints
        let wants = Procedure(
            signature: Signature(parameters: ["word": Parameter(type: .string)]),
            body: []
        )
        let sut = Module(
            procedures: [
                "wants": wants,
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["counts": Parameter(type: .array(.int))]
                    ),
                    body: [
                        Statement(
                            id: "head",
                            expression: .dispatch(Dispatch(
                                receiver: reference("counts"),
                                selector: "std.collection.first"
                            ))
                        ),
                        Statement(
                            id: "asked",
                            expression: .dispatch(Dispatch(
                                selector: "wants",
                                arguments: ["word": reference("head")]
                            ))
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

    @Test("a hole a procedure answers becomes what the walk answers")
    func aWalkAnswersWhatItsProcedureDoes() throws {
        // Given — `map` over strings with a procedure answering int. What the
        // walk answers follows the procedure rather than the receiver, so asking
        // for the receiver's shape back is the disagreement
        let counting = Procedure(
            signature: Signature(
                parameters: ["item": Parameter(type: .string)],
                returns: .int
            ),
            body: [],
            result: .dispatch(Dispatch(receiver: reference("item"), selector: "count"))
        )
        let wants = Procedure(
            signature: Signature(parameters: ["ns": Parameter(type: .array(.string))]),
            body: []
        )
        let sut = Module(
            procedures: [
                "wants": wants,
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["names": Parameter(type: .array(.string))]
                    ),
                    body: [
                        Statement(
                            id: "sizes",
                            expression: .dispatch(Dispatch(
                                receiver: reference("names"),
                                selector: "std.collection.map",
                                arguments: ["value": .closure(counting)]
                            ))
                        ),
                        Statement(
                            id: "asked",
                            expression: .dispatch(Dispatch(
                                selector: "wants",
                                arguments: ["ns": reference("sizes")]
                            ))
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

    // MARK: - Test
    @Test("a name bound to a call carries that call's declared answer")
    func boundCallCarriesItsAnswer() throws {
        // Given
        let sut = Module(
            procedures: [
                "counts": Procedure(
                    signature: Signature(
                        returns: .int
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.int(1))
                        )
                    ]
                ),
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "many",
                            expression: .dispatch(Dispatch(selector: "counts"))
                        ),
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "wants", arguments: [
                                        "word": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("ok"))
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

    @Test("a field of a declared shape carries the field's type")
    func declaredShapeCarriesItsFields() throws {
        // Given
        let sut = Module(
            types: [
                "Task": .record([
                        "done": .bool,
                        "id": .string
                    ])
            ],
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "task": Parameter(type: .named("Task"))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "wants", arguments: [
                                        "word": .reference([.key("task"), .key("done")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then — `task.done` is a bool, and the walk read that from the
        // shape rather than from the value
        #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a path that ends in a word carries what the word answers")
    func pathWordCarriesItsAnswer() throws {
        // Given — `${names.count}` is `count` sent to `names`, and `count`
        // declares that it answers an int
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "names": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "wants", arguments: [
                                        "word": .reference([.key("names"), .key("count")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("ok"))
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

    @Test("an element of an iteration carries the material's element type")
    func iterationElementIsTyped() throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "counts": Parameter(type: .array(.int))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "round",
                            expression: .iteration(over: .reference([.key("counts")]), body: [
                                        Statement(
                                            id: "said",
                                            expression: .dispatch(Dispatch(selector: "wants", arguments: [
                                                        "word": .reference([.key("round"), .key("item")])
                                                    ]))
                                        )
                                    ], element: "round")
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("ok"))
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

    @Test("a name a branch may have rewritten holds neither reading")
    func disagreeingWritesAreUnknown() throws {
        // Given — a join that guessed would be a refusal an author cannot act
        // on, so where two readings disagree nothing is claimed
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "flag": Parameter(type: .bool)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "held",
                            binding: .variable,
                            expression: .literal(.int(1))
                        ),
                        Statement(
                            id: "gate",
                            expression: .conditional(equals(
                                        .reference([.key("flag")]),
                                        .literal(.bool(true))
                                        ), then: Block(body: [
                                        Statement(
                                            id: "held",
                                            binding: .assignment,
                                            expression: .literal(.string("text"))
                                        )
                                    ]), else: nil)
                        ),
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "wants", arguments: [
                                        "word": .reference([.key("held")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try language.link([sut] + Module.standard, entry: entryName)
    }

    @Test("a declared answer is checked against what the body actually names")
    func rightTypesLink() throws {
        // Given — the same shapes, agreeing
        let sut = Module(
            procedures: [
                "counts": Procedure(
                    signature: Signature(
                        returns: .int
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.int(1))
                        )
                    ]
                ),
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "names": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "many",
                            expression: .dispatch(Dispatch(selector: "counts"))
                        ),
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "wants", arguments: [
                                        "word": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try language.link([sut] + Module.standard, entry: entryName)
    }

    @Test("what a map answers is typed by the closure it was given")
    func aMapAnswerCarriesItsElementType() throws {
        // Given — `map` declares its answer through holes: the closure's
        // declared answer fills `Answer`, so handing the fan-out's answer to a
        // word that wants another kind is refused before anything runs
        let sut = Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "kept",
                            expression: .dispatch(
                                Dispatch(
                                    receiver: .literal(.array([.int(1), .int(2)])),
                                    selector: "std.concurrent.map",
                                    arguments: [
                                        "by": .closure(
                                            Procedure(
                                                signature: Signature(
                                                    parameters: ["item": Parameter(type: .int)],
                                                    returns: .int
                                                ),
                                                body: [],
                                                result: reference("item")
                                            )
                                        )
                                    ]
                                )
                            )
                        ),
                        Statement(
                            id: "said",
                            expression: .dispatch(
                                Dispatch(
                                    selector: "wants",
                                    arguments: ["words": reference("kept")]
                                )
                            )
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: ["words": Parameter(type: .array(.string))]
                    ),
                    body: [
                        Statement(id: "done", expression: .literal(.string("ok")))
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }
    }

    @Test("a branch with no other arm holds what it answers when it declines")
    func aBranchWithoutAnElseAnswersNull() throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "ready": Parameter(type: .bool)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "many",
                            expression: .conditional(
                                .reference([.key("ready")]),
                                then: Block(
                                    body: [],
                                    result: refusing(literal("no"))
                                ),
                                else: nil
                            )
                        ),
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "wants", arguments: [
                                        "word": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("ok"))
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

    @Test("a path drilling a field into a shape that has none is refused")
    func drillingIntoAShapeWithoutFieldsIsRefused() throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "count": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .reference([.key("count"), .key("nope")])
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

    @Test("a path indexing into something that is not an array is refused")
    func indexingIntoANonArrayIsRefused() throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "name": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .reference([.key("name"), .index(0)])
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

    @Test("a path naming a word of the shape it reached is not refused")
    func aWordReachedFromAPathIsAllowed() throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "names": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .reference([.key("names"), .key("count")])
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try language.link([sut] + Module.standard, entry: entryName)
    }

    @Test("a field the walk could not read says nothing, so nothing is refused")
    func anUnreadShapeIsNotRefused() throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "payload": Parameter(type: .any)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .reference([.key("payload"), .key("whatever")])
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try language.link([sut] + Module.standard, entry: entryName)
    }

    @Test("a record may carry more than it declares, so a missing field is not refused")
    func aRecordIsNotClosed() throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "task": Parameter(type: .record(["id": .string]))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .reference([.key("task"), .key("done")])
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try language.link([sut] + Module.standard, entry: entryName)
    }

    @Test("an arm that refuses does not cost the arm that answers its type")
    func refusingArmKeepsTheOtherArmsType() throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "ready": Parameter(type: .bool)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "many",
                            expression: .conditional(
                                .reference([.key("ready")]),
                                then: Block(body: [], result: .literal(.int(1))),
                                else: Block(body: [], result: refusing(literal("no")))
                            )
                        ),
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "wants", arguments: [
                                        "word": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("ok"))
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

    @Test("an attempt whose body only refuses holds what the rescue answers")
    func attemptHoldsTheRescueWhenTheBodyRefuses() throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "many",
                            expression: .attempt(
                                Block(body: [], result: refusing(literal("no"))),
                                rescue: Block(body: [], result: .literal(.string("fallback"))),
                                failure: "why"
                            )
                        ),
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "wants", arguments: [
                                        "word": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("ok"))
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

    @Test("a name on a call that never finishes is refused at link")
    func refusingBodySaysNothingAboutItsAnswer() throws {
        // Given — `gives_up` declares never, so a name on its call promises a
        // binding that cannot happen. The link refuses the name where the
        // signature is known, rather than inventing a type for the binding
        let sut = Module(
            procedures: [
                "gives_up": Procedure(
                    signature: Signature(
                        returns: .never
                    ),
                    body: [
                        Statement(
                            id: "no",
                            expression: refusing(literal("no"))
                        )
                    ]
                ),
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "many",
                            expression: .dispatch(Dispatch(selector: "gives_up"))
                        ),
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "wants", arguments: [
                                        "word": .reference([.key("many")])
                                    ]))
                        )
                    ]
                ),
                "wants": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("ok"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect {
            try language.link([sut] + Module.standard, entry: entryName)
        } throws: { error in
            "\(error)".contains("never finishes")
        }
    }
}
