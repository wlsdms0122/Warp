//
//  ReceiverTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// `${x.count}` works because `count` is a declaration, and so is anything else
// that declares a receiver — which is the whole of what method syntax means here.
// It is not reserved for native code.
@Suite("A declaration may be sent to something")
struct ReceiverTests {
    // MARK: - Property
    private let language = Language()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a declared receiver is read by the name the signature gave it")
    func receiverIsANamedParameter() async throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "word": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .dispatch(Dispatch(selector: "shout", arguments: [
                                        "of": .reference([.key("word")])
                                    ]))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("said")])
                        ])
                ),
                "shout": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .string)
                        ],
                        returns: .string
                    ),
                    body: [
                        Statement(
                            id: "loud",
                            expression: interpolated(
                                spelling(reference("of")),
                                literal("!")
                            )
                        )
                    ],
                    result: .reference([.key("loud")])
                )
            ]
        )

        // When
        let outputs = try await run(sut, arguments: ["word": .string("hey")])

        // Then
        #expect(outputs["result"] == .string("hey!"))
    }

    @Test("a native word and a written one are declared the same way")
    func nativeAndWrittenDeclareAlike() throws {
        // Given
        let written = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("end"))
                        )
                    ]
                ),
                "shout": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .string)
                        ],
                        returns: .string
                    ),
                    body: [
                        Statement(
                            id: "loud",
                            expression: .reference([.key("of")])
                        )
                    ]
                )
            ]
        )

        // When
        let image = try language.link([written] + Module.standard, entry: entryName)

        // Then — one table, and what separates them is only how each is written
        let shout = try #require(image.derivations["shout"])
        let count = try #require(image.derivations["count"])

        #expect(shout.signature.receiver == "of")
        #expect(count.signature.receiver == "of")
        #expect(shout.block != nil)
        #expect(count.block == nil)
    }

    @Test("a call sends its receiver even where the parameter is required")
    func receiverSuppliesItsParameter() async throws {
        // Given — the receiver is written on the other side of the dot, so the
        // linker must not read its parameter as one nobody supplied
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
                            id: "many",
                            expression: .reference([.key("names"), .key("count")])
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("many")])
                        ])
                )
            ]
        )

        // When
        let outputs = try await run(
            sut,
            arguments: ["names": .array([.string("a"), .string("b")])]
        )

        // Then
        #expect(outputs["result"] == .int(2))
    }

    @Test("what answers without running is worked out at link, not declared")
    func purityIsALinkFact() throws {
        // Given
        let sut = Module(
            procedures: [
                "clean": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.int(1))
                        )
                    ]
                ),
                "dirty": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .dispatch(Dispatch(selector: "fail", arguments: [
                                        "recoverable": .literal(.bool(true))
                                    ]))
                        )
                    ]
                ),
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "a",
                            expression: .dispatch(Dispatch(selector: "clean"))
                        ),
                        Statement(
                            id: "b",
                            expression: .dispatch(Dispatch(selector: "dirty"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard + [.failing], entry: entryName)

        // Then — `clean` computes; `dirty` reaches an effect, and everything
        // that reaches it goes with it
        #expect(image.pure.contains("clean"))
        #expect(!image.pure.contains("dirty"))
        #expect(!image.pure.contains("entry"))
        #expect(image.pure.contains("std.collection.count"))
    }

    @Test("a body that sends a word is still something a path may reach")
    func aBodyThatSendsIsStillPure() throws {
        // Given — purity is judged over the name a body wrote, and what that
        // name means depends on where it was written. `label` sends `joined`,
        // which is pure, so `label` is pure and a path may reach it
        let label = Procedure(
            signature: Signature(
                receiver: "of",
                parameters: ["of": Parameter(type: .array(.string))],
                returns: .string
            ),
            body: [],
            result: .dispatch(Dispatch(receiver: reference("of"), selector: "joined"))
        )
        let sut = Module(
            procedures: [
                "label": label,
                entryName: Procedure(
                    signature: Signature(
                        parameters: ["names": Parameter(type: .array(.string))]
                    ),
                    body: [],
                    result: reference("names", "label")
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard, entry: entryName)

        // Then
        #expect(image.pure.contains("label"))
        #expect(image.derivations["label"] != nil)
    }

    @Test("a procedure someone wrote is reachable from a path")
    func writtenProcedureIsReachableFromAPath() async throws {
        // Given — this is what unifying bought. `summarize` is a body, not
        // native, and `${tasks.summarize}` reaches it because the link proved it
        // answers without running.
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "tasks": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .reference([.key("tasks"), .key("summarize")])
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("said")])
                        ])
                ),
                "summarize": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.string))
                        ],
                        returns: .string
                    ),
                    body: [
                        Statement(
                            id: "how_many",
                            expression: .reference([.key("of"), .key("count")])
                        ),
                        Statement(
                            id: "line",
                            expression: interpolated(
                                spelling(reference("how_many")),
                                literal(" tasks")
                            )
                        )
                    ],
                    result: .reference([.key("line")])
                )
            ]
        )

        // When
        let outputs = try await run(
            sut,
            arguments: ["tasks": .array([.string("a"), .string("b"), .string("c")])]
        )

        // Then
        #expect(outputs["result"] == .string("3 tasks"))
    }

    @Test("a body that reaches an effect is not reachable from a path")
    func impureProcedureIsNotReachableFromAPath() throws {
        // Given — the proof is what opens the path, so losing it closes it
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "tasks": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .literal(.string("nothing reaches it"))
                        )
                    ]
                ),
                "summarize": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "boom",
                            expression: .dispatch(Dispatch(selector: "fail", arguments: [
                                        "recoverable": .literal(.bool(false))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try language.link([sut] + Module.standard + [.failing], entry: entryName)

        // Then
        #expect(!image.pure.contains("summarize"))
        #expect(image.derivations["summarize"] == nil)
    }

    @Test("a path to a body that reaches an effect is refused before any run")
    func aPathToAnImpureProcedureIsRefused() throws {
        // Given — the same shape, reached
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "tasks": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "said",
                            expression: .reference([.key("tasks"), .key("summarize")])
                        )
                    ]
                ),
                "summarize": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [
                        Statement(
                            id: "boom",
                            expression: .dispatch(Dispatch(selector: "fail", arguments: [
                                        "recoverable": .literal(.bool(false))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard + [.failing], entry: entryName)
        }
    }

    @Test("a word reached from a path is checked against the receiver it declared")
    func aPathChecksTheReceiver() async throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "subject": Parameter(type: .any)
                        ]
                    ),
                    body: [],
                    result: .reference([.key("subject"), .key("size")])
                ),
                "size": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.any))
                        ],
                        returns: .int
                    ),
                    body: [],
                    result: .reference([.key("of"), .key("count")])
                )
            ]
        )

        // When
        let answered = try await run(sut, arguments: ["subject": .array([.string("a")])])

        // Then
        #expect(answered == .int(1))

        // A string is not an array. Counting its characters would be an answer
        // the declaration says this word does not give.
        await #expect(throws: (any Error).self) {
            try await run(sut, arguments: ["subject": .string("ab")])
        }
    }

    @Test("a word reached from a path takes the defaults it declared")
    func aPathAppliesDefaults() async throws {
        // Given
        let sut = Module(
            procedures: [
                "entry": Procedure(
                    signature: Signature(
                        parameters: [
                            "subject": Parameter(type: .array(.string))
                        ]
                    ),
                    body: [],
                    result: .reference([.key("subject"), .key("label")])
                ),
                "label": Procedure(
                    signature: Signature(
                        receiver: "of",
                        parameters: [
                            "of": Parameter(type: .array(.any)),
                            "prefix": Parameter(type: .string, default: .string("size"))
                        ],
                        returns: .string
                    ),
                    body: [
                        Statement(
                            id: "many",
                            expression: .reference([.key("of"), .key("count")])
                        )
                    ],
                    result: interpolated(
                        spelling(reference("prefix")),
                        literal(": "),
                        spelling(reference("many"))
                    )
                )
            ]
        )

        // When
        let answered = try await run(
            sut,
            arguments: ["subject": .array([.string("a"), .string("b")])]
        )

        // Then
        #expect(answered == .string("size: 2"))
    }

    @Test("a word that refuses mid-path says why, rather than reading as absence")
    func aRefusalInAPathIsNotAbsence() async throws {
        // Given — `floored` takes a double and then finds no whole answer. That
        // is not the word declining the shape, so reporting nothing was there
        // would report the one thing known to be false.
        let sut = reference("x", "floored")

        // When / Then
        await #expect {
            try await answer(
                of: [Statement(id: "probe", expression: sut)],
                result: reference("probe"),
                arguments: ["x": .double(1e30)],
                signature: Signature(parameters: ["x": Parameter(type: .double)])
            )
        } throws: { error in
            "\(error)".contains("no whole answer")
        }
    }

    @Test("a word that answers never is not something a path may reach")
    func neverIsNotDerivable() {
        // Given — a walk decides on its own whether to send what it reaches, and
        // leaving is not a decision a walk gets to make quietly
        let sut = Module.control.procedures["abort"]

        // When / Then
        #expect(sut?.signature.isDerivable == false)
    }
}
