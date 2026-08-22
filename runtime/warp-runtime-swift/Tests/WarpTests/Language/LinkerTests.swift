//
//  LinkerTests.swift
//  WarpTests
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Testing
@testable import Warp

// Linking, asked the way a caller asks it: modules loaded from documents, handed
// over as a set, and one name to start from.
@Suite
struct LinkerTests {
    // MARK: - Property
    private let language = Language()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a constant that cannot be settled says why, not that it is a cycle")
    func aRefusedConstantSaysWhy() throws {
        // Given — `greeting` names nothing that is missing, so the only reason
        // it fails is its own: `text` refuses to spell nothing
        let sut = Module(
            name: "app",
            constants: [
                "greeting": .dispatch(Dispatch(receiver: .literal(.null), selector: "text"))
            ],
            procedures: [entryName: Procedure(body: [])]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("greeting") == true)
        #expect(
            error?.message.contains("names it back") == false,
            "a refusal of its own was reported as a cycle"
        )
    }

    @Test("a default the parameter itself would refuse is refused at link")
    func aDefaultOutsideTheTypeIsRefused() {
        // Given — the fallback only ever runs for the one call that leans on
        // it, which is exactly the call that could not see this coming
        let sut = Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: [
                            "count": Parameter(type: .int, default: .string("three"))
                        ]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("helper.inputs.count") == true)
    }

    @Test("a default outside its own oneOf is refused at link")
    func aDefaultOutsideOneOfIsRefused() {
        // Given
        let sut = Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: [
                            "mode": Parameter(
                                type: .string,
                                oneOf: ["fast", "slow"],
                                default: .string("medium")
                            )
                        ]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("helper.inputs.mode") == true)
    }

    @Test("an omitted argument arrives as the settled default")
    func aDefaultArrivesSettled() async throws {
        // Given — the fallback walks the same gate an argument does, so a whole
        // number defaulting a fraction slot arrives as the fraction it settles to
        let answer = try await answer(
            of: [],
            result: reference("count"),
            signature: Signature(
                parameters: ["count": Parameter(type: .double, default: .int(1))]
            )
        )

        // Then — Swift-level equality is kind-strict, so this is the settled kind
        #expect(answer == .double(1))
    }

    @Test("a oneOf no candidate of which fits the type is refused at link")
    func anUnsatisfiableOneOfIsRefused() {
        // Given — admitting nothing is a fact about the type and the set
        // together, not about the set being empty
        let sut = Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: ["count": Parameter(type: .int, oneOf: ["fast"])]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("admits nothing") == true)
    }

    @Test("a null default on a type that does not admit null is refused at link")
    func aNullDefaultOutsideTheTypeIsRefused() {
        // Given — the explicitly-null default is the value the body receives,
        // so the declaration must admit it like any other value
        let sut = Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: ["word": Parameter(type: .string, default: .null)]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("null") == true)
    }

    @Test("a parameter nested in a procedure type is judged like a top-level one")
    func aNestedParameterDeclarationIsJudged() {
        // Given — the declaration facts are the same wherever the parameter is
        // written, so the judgment rides the same recursion that resolves the
        // nested type names
        let sut = Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: [
                            "by": Parameter(
                                type: .procedure(
                                    Signature(
                                        parameters: [
                                            "mode": Parameter(type: .string, oneOf: [])
                                        ],
                                        returns: .bool
                                    )
                                )
                            )
                        ]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("admits nothing") == true)
    }

    @Test("a oneOf that admits nothing is refused at link")
    func anEmptyOneOfIsRefused() {
        // Given — no call could ever fit it, so the declaration is the defect
        let sut = Module(
            procedures: [
                entryName: Procedure(body: []),
                "helper": Procedure(
                    signature: Signature(
                        parameters: ["mode": Parameter(type: .string, oneOf: [])]
                    ),
                    body: []
                )
            ]
        )

        // When / Then
        let error = #expect(throws: LinkError.self) {
            try language.link([sut] + Module.standard, entry: entryName)
        }

        #expect(error?.message.contains("admits nothing") == true)
    }

    @Test("a constant may reach a word the same way a body does")
    func aConstantReachesAWord() async throws {
        // Given — folding happens after the words are known, so a constant that
        // interpolates is a constant that sends
        let sut = Module(
            name: "app",
            constants: [
                "host": .literal(.string("warp.dev")),
                "url": .dispatch(
                    Dispatch(
                        receiver: .array([
                            .literal(.string("https://")),
                            .dispatch(Dispatch(receiver: reference("host"), selector: "text"))
                        ]),
                        selector: "joined"
                    )
                )
            ],
            procedures: [entryName: Procedure(body: [], result: reference("url"))]
        )

        // When
        let answer = try await run(sut)

        // Then
        #expect(answer == .string("https://warp.dev"))
    }

    @Test("a call on a path this run would never take is still resolved")
    func unreachedCallIsLinked() throws {
        // Given — the else arm cannot be taken with this input, and the warrant
        // for checking it anyway is compilation: unreached code still compiles
        let sut = Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(
                            id: "pick",
                            expression: .conditional(equals(
                                        .literal(.string("yes")),
                                        .literal(.string("yes"))
                                        ), then: Block(body: [
                                        Statement(
                                            id: "safe",
                                            expression: .literal(.string("fine"))
                                        )
                                    ]), else: Block(body: [
                                        Statement(
                                            id: "risky",
                                            expression: .dispatch(Dispatch(selector: "missing"))
                                        )
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut], entry: "caller")
        }
    }

    @Test("a call inside a rescue body is resolved")
    func rescueBodyIsLinked() throws {
        // Given
        let sut = Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(
                            id: "attempt",
                            expression: .attempt(Block(body: [
                                        Statement(
                                            id: "attempt",
                                            expression: .dispatch(Dispatch(selector: "fail", arguments: [
                                                        "recoverable": .literal(.bool(true))
                                                    ]))
                                        )
                                    ]), rescue: Block(body: [
                                        Statement(
                                            id: "recover",
                                            expression: .dispatch(Dispatch(selector: "missing"))
                                        )
                                    ]), failure: "attempt")
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut], entry: "caller")
        }
    }

    @Test("resolution follows the callee's own calls")
    func linkingIsTransitive() throws {
        // Given — `caller` names nothing missing; `middle` does
        let sut = Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(
                            id: "call",
                            expression: .dispatch(Dispatch(selector: "middle"))
                        )
                    ]
                ),
                "middle": Procedure(
                    body: [
                        Statement(
                            id: "deeper",
                            expression: .dispatch(Dispatch(selector: "leaf"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut], entry: "caller")
        }
    }

    @Test("names resolve across every module in the link, flat")
    func symbolsResolveAcrossModules() throws {
        // Given — no module says anything about the others; what to link is the
        // caller's statement and joining the names up is the linker's work
        let caller = Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(
                            id: "call",
                            expression: .dispatch(Dispatch(selector: "middle"))
                        )
                    ]
                )
            ]
        )
        let middle = Module(
            procedures: [
                "middle": Procedure(
                    body: [
                        Statement(
                            id: "deeper",
                            expression: .dispatch(Dispatch(selector: "leaf"))
                        )
                    ]
                )
            ]
        )
        let leaf = Module(
            procedures: [
                "leaf": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("end"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try language.link([caller, middle, leaf], entry: "caller")

        // Then
        #expect(Set(image.procedures.keys) == ["caller", "middle", "leaf"])
    }

    @Test("a module left out of the link is a module that does not exist")
    func omittedModuleIsUnresolved() throws {
        // Given — the set is the whole world, so leaving one out is not a
        // lookup that fails later but a name nothing declares
        let caller = Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(
                            id: "call",
                            expression: .dispatch(Dispatch(selector: "leaf"))
                        )
                    ]
                )
            ]
        )
        let leaf = Module(
            procedures: [
                "leaf": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("end"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([caller], entry: "caller")
        }
        #expect(throws: Never.self) {
            try language.link([caller, leaf], entry: "caller")
        }
    }

    @Test("two modules declaring one name are refused")
    func duplicateSymbolIsRefused() throws {
        // Given — one flat namespace is what taking the whole world at once
        // costs, and two declarations of a name have no way to be told apart
        let left = Module(
            procedures: [
                "shared": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("left"))
                        )
                    ]
                )
            ]
        )
        let right = Module(
            procedures: [
                "shared": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("right"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([left, right], entry: "shared")
        }
    }

    @Test("an entry nothing declares is refused")
    func missingEntryIsRefused() throws {
        // Given
        let sut = Module(
            procedures: [
                "present": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("end"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut], entry: "absent")
        }
    }

    @Test("any declaration can be the entry")
    func anyProcedureCanBeTheEntry() async throws {
        // Given — nothing marks one of them, so which runs is this argument
        let sut = Module(
            procedures: [
                "first": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("from-first"))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("done")])
                        ])
                ),
                "second": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("from-second"))
                        )
                    ],
                    result: .record([
                            "result": .reference([.key("done")])
                        ])
                )
            ]
        )

        // When
        let first = try await run(sut, entry: "first")
        let second = try await run(sut, entry: "second")

        // Then
        #expect(first["result"] == .string("from-first"))
        #expect(second["result"] == .string("from-second"))
    }

    @Test("a self-recursive procedure links once instead of forever")
    func recursiveProcedureLinksOnce() throws {
        // Given
        let sut = Module(
            procedures: [
                "loopy": Procedure(
                    body: [
                        Statement(
                            id: "again",
                            expression: .dispatch(Dispatch(selector: "loopy"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try language.link([sut], entry: "loopy")

        // Then
        #expect(Set(image.procedures.keys) == ["loopy"])
    }

    @Test("an argument the callee never declared is refused")
    func undeclaredArgumentIsRefused() throws {
        // Given
        let sut = Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            "base": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "echo",
                            expression: .reference([.key("base")])
                        )
                    ]
                ),
                "caller": Procedure(
                    body: [
                        Statement(
                            id: "call",
                            expression: .dispatch(Dispatch(selector: "callee", arguments: [
                                        "base": .literal(.int(1)),
                                        "bonus": .literal(.int(2))
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut], entry: "caller")
        }
    }

    @Test("a required argument nobody passes is refused")
    func missingRequiredArgumentIsRefused() throws {
        // Given
        let sut = Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            "base": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "echo",
                            expression: .reference([.key("base")])
                        )
                    ]
                ),
                "caller": Procedure(
                    body: [
                        Statement(
                            id: "call",
                            expression: .dispatch(Dispatch(selector: "callee"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut], entry: "caller")
        }
    }

    @Test("an argument named rather than written is judged by what the name holds")
    func referenceArgumentIsJudged() throws {
        // Given — the type is wrong, and both sides said so in their own text:
        // `text` was declared a string and `base` is declared an int
        let sut = Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            "base": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "echo",
                            expression: .reference([.key("base")])
                        )
                    ]
                ),
                "caller": Procedure(
                    signature: Signature(
                        parameters: [
                            "text": Parameter(type: .string)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "call",
                            expression: .dispatch(Dispatch(selector: "callee", arguments: [
                                        "base": .reference([.key("text")])
                                    ]))
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect(throws: LinkError.self) {
            try language.link([sut], entry: "caller")
        }
    }

    @Test("what nothing declared is not something the link can be wrong about")
    func undeclaredArgumentIsNotJudged() throws {
        // Given — `held` comes back from a call that declares no answer, so
        // nothing is known about it and nothing is refused. That is the bound on
        // the promise: inference answers where the text says so and `any`
        // everywhere else.
        let sut = Module(
            procedures: [
                "callee": Procedure(
                    signature: Signature(
                        parameters: [
                            "base": Parameter(type: .int)
                        ]
                    ),
                    body: [
                        Statement(
                            id: "echo",
                            expression: .reference([.key("base")])
                        )
                    ]
                ),
                "caller": Procedure(
                    body: [
                        Statement(
                            id: "held",
                            expression: .dispatch(Dispatch(selector: "opaque"))
                        ),
                        Statement(
                            id: "call",
                            expression: .dispatch(Dispatch(selector: "callee", arguments: [
                                        "base": .reference([.key("held")])
                                    ]))
                        )
                    ]
                ),
                "opaque": Procedure(
                    body: [
                        Statement(
                            id: "made",
                            expression: .literal(.string("whatever"))
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try language.link([sut], entry: "caller")
    }

    @Test("a procedure that calls nothing links alone")
    func selfContainedProcedureLinks() throws {
        // Given
        let sut = Module(
            procedures: [
                "alone": Procedure(
                    body: [
                        Statement(
                            id: "done",
                            expression: .literal(.string("end"))
                        )
                    ]
                )
            ]
        )

        // When
        let image = try language.link([sut], entry: "alone")

        // Then
        #expect(Set(image.procedures.keys) == ["alone"])
    }

    @Test("a bare name two modules declare is refused, naming both")
    func aBareNameTwoModulesDeclareIsRefused() {
        // Given — `map` is a collection word and a concurrent word on purpose,
        // and this asymmetry is the contract: the bare spelling resolves only
        // while exactly one linked module declares it
        let sut = Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(
                            id: "walked",
                            expression: .dispatch(
                                Dispatch(
                                    receiver: .literal(.array([])),
                                    selector: "map",
                                    arguments: [
                                        "by": .closure(
                                            Procedure(body: [], result: .literal(.int(0)))
                                        )
                                    ]
                                )
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then — the refusal names both candidates, which is the whole
        // of what a caller needs to pick one
        #expect {
            try language.link([sut] + Module.standard, entry: "caller")
        } throws: { error in
            "\(error)".contains("std.collection.map")
                && "\(error)".contains("std.concurrent.map")
        }
    }

    @Test("a bare name one module declares still resolves beside the full link")
    func aUniqueBareNameResolves() throws {
        // Given — `all` stayed unique because `std.logic` moved to `and`/`or`;
        // this holds that clearing to its purpose
        let sut = Module(
            procedures: [
                "caller": Procedure(
                    body: [
                        Statement(
                            id: "both",
                            expression: .dispatch(
                                Dispatch(
                                    receiver: .array([
                                        .closure(Procedure(body: [], result: .literal(.int(1))))
                                    ]),
                                    selector: "all"
                                )
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then
        _ = try language.link([sut] + Module.standard, entry: "caller")
    }
}
