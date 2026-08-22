//
//  SwiftAuthoringTests.swift
//  WarpTests
//
//  Created by JSilver on 8/16/26.
//

import Testing
@testable import Warp

// The kernel's own acceptance test: a procedure written in Swift, run without a
// front end. Nothing here spells a keyword — no `"loop"`, no `"steps"`, no path
// string — because a caller that reaches for `import Warp` is writing the IR,
// not a document about it. If a construct cannot be reached from here, it is
// only reachable through a notation, and the notation has become the language.
@Suite("Authoring a procedure in Swift")
struct SwiftAuthoringTests {
    // MARK: - Lifecycle
    // MARK: - Test
    @Test("hello world needs no front end")
    func helloWorld() async throws {
        // Given
        let sut = Language()
        let procedure = Procedure(
            body: [
                Statement(id: "greet", expression: .literal(.string("hello, world")))
            ],
            result: .record(["greeting": .reference([.key("greet")])])
        )

        // When
        let image = try sut.link(
            [Module(procedures: ["greet": procedure]), .shouting] + Module.standard,
            entry: "greet"
        )
        let outputs = try await sut.makeExecutor().run(image)

        // Then
        #expect(outputs["greeting"] == .string("hello, world"))
    }

    @Test("control flow and the signature are reachable from Swift alone")
    func controlFlow() async throws {
        // Given
        let sut = Language()
        let index = Expression.reference([.key("counted"), .key("index")])
        let procedure = Procedure(
            signature: Signature(parameters: ["rounds": Parameter(type: .int)]),
            body: [
                Statement(
                    id: "counted",
                    expression: .loop(
                        while: differs(
                            index,
                            .reference([.key("rounds")])
                            ),
                        body: Block(
                            body: [Statement(id: "tick", expression: index)],
                            result: index
                        ),
                        round: "counted"
                    )
                ),
                Statement(
                    id: "verdict",
                    expression: .conditional(
                        equals(
                            .reference([.key("counted")]),
                            .literal(.int(3))
                            ),
                        then: Block(body: [], result: .literal(.string("counted to three"))),
                        else: Block(body: [], result: .literal(.string("counted otherwise")))
                    )
                )
            ],
            result: .record(["verdict": .reference([.key("verdict")])])
        )

        // When
        // Comparing is a word, so this links the bundle that declares one — the
        // control flow beside it needs nothing.
        let image = try sut.link(
            [Module(procedures: ["entry": procedure]), .logic],
            entry: "entry"
        )
        let outputs = try await sut.makeExecutor().run(
            image,
            arguments: ["rounds": .int(3)]
        )

        // Then
        #expect(outputs["verdict"] == .string("counted to three"))
    }

    @Test("a native effect needs no decoder to run")
    func hostEffectWithoutDecoder() async throws {
        // Given
        let sut = Language()
        let procedure = Procedure(
            body: [
                Statement(
                    id: "shout",
                    expression: .dispatch(
                        Dispatch(
                            selector: "shout",
                            arguments: ["text": .literal(.string("hey"))]
                        )
                    )
                )
            ],
            result: .record(["shout": .reference([.key("shout")])])
        )

        // When
        let image = try sut.link(
            [Module(procedures: ["greet": procedure]), .shouting] + Module.standard,
            entry: "greet"
        )
        let outputs = try await sut.makeExecutor().run(image)

        // Then
        #expect(outputs["shout"] == .string("HEY"))
    }

    @Test("a library word, a native word and a procedure are all one expression")
    func oneCallingShape() async throws {
        // Given — three selectors that are answered in three different places,
        // written identically. Where each is found is the runtime's business.
        let sut = Language()
        let procedure = Procedure(
            body: [
                Statement(id: "names", expression: .literal(.array([.string("a")]))),
                Statement(
                    id: "counted",
                    expression: .dispatch(
                        Dispatch(receiver: .reference([.key("names")]), selector: "count")
                    )
                ),
                Statement(
                    id: "shouted",
                    expression: .dispatch(
                        Dispatch(selector: "shout", arguments: ["text": .literal(.string("hi"))])
                    )
                ),
                Statement(
                    id: "called",
                    expression: .dispatch(
                        Dispatch(selector: "echo", arguments: ["word": .literal(.string("yo"))])
                    )
                )
            ],
            result: .record([
                "counted": .reference([.key("counted")]),
                "shouted": .reference([.key("shouted")]),
                "called": .reference([.key("called"), .key("said")])
            ])
        )
        // A second declaration, in the same module — a call names a symbol, and
        // which module declared it is the linker's business.
        let echo = Procedure(
            signature: Signature(parameters: ["word": Parameter(type: .string)]),
            body: [],
            result: .record(["said": .reference([.key("word")])])
        )

        // When
        let image = try sut.link(
            [Module(procedures: ["speak": procedure, "echo": echo]), .shouting] + Module.standard,
            entry: "speak"
        )
        let outputs = try await sut.makeExecutor().run(image)

        // Then
        #expect(outputs["counted"] == .int(1))
        #expect(outputs["shouted"] == .string("HI"))
        #expect(outputs["called"] == .string("yo"))
    }
}

// A word written in Swift and never taught to a document to spell. It conforms
// to `Effect` and to nothing else — the proof that the run path asks for no
