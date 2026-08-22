//
//  WriterTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// Writing is how a program leaves the machine that built it, so what it promises
// is not that the text comes back the same — it is that the program does. A
// document arrives spelled however its author liked it and is written back in
// the shapes the language actually has, which is why writing twice is the
// question these ask: the first pass says what the program is, and the second
// has to agree.
@Suite("A program can be written back out as a document")
struct WriterTests {
    // MARK: - Property
    private let loader = Loader.testing
    private let sut = Writer()

    // MARK: - Initializer
    // MARK: - Test
    @Test("every construct survives being written and read back", arguments: Self.corpus)
    func writingIsAFixedPoint(_ document: Value) throws {
        // Given
        let once = try sut.value(of: try loader.load(document))

        // When
        let twice = try sut.value(of: try loader.load(once))

        // Then
        #expect(once == twice)
    }

    @Test("a program nobody wrote a document for still round-trips", arguments: Self.assembled)
    func writingIsAFixedPointForAssembledPrograms(_ module: Module) throws {
        // Given — every other corpus here starts from a document, so what they
        // check is that documents survive. The half this direction exists for is
        // the other one: a program built by hand, which no reader has ever seen
        // and no notation has had a chance to normalise.
        let once = try sut.value(of: module)

        // When
        let twice = try sut.value(of: try loader.load(once))

        // Then
        #expect(once == twice)
    }

    @Test("a canonical document is written back exactly as it was")
    func aCanonicalDocumentIsWrittenBackUnchanged() throws {
        // Given — `canonical` is written in the shapes themselves, so reading it
        // and writing it must arrive at the same document. A fixed point only
        // says the writing settled; this says nothing was left behind, because
        // every slot the language has is written down here and a slot that
        // stopped being written would go missing from the answer.
        let sut = try sut.value(of: try loader.load(Self.canonical))

        // Then
        #expect(sut == Self.canonical)
    }

    @Test("nothing written is spelled", arguments: Self.corpus)
    func nothingWrittenIsSpelled(_ document: Value) throws {
        // Given — the corpus is written with every spelling the notation has.
        // What comes back may use none of them, because a spelling is a rule the
        // reading side would have to implement the same way, and the reading
        // side is somewhere else.
        let written = try sut.value(of: try loader.load(document))

        // When
        let spellings = Set(Spelling.operators.keys).union(["format", "with"])

        // Then
        #expect(Self.keys(in: written).isDisjoint(with: spellings))
    }

    @Test("a written program runs the way the one it came from did")
    func aWrittenProgramRunsTheSame() async throws {
        // Given — a fixed point says the writing settled, not that it kept
        // everything. Running both is what notices a slot dropped on the way out.
        let document: Value = [
            "needs": ["plus", "std.logic.equal", "std.text.joined", "std.text.text"],
            "procedures": [
                "entry": [
                    "parameters": ["names": "array<string>", "word": "string"],
                    "body": [
                        [
                            "id": "pick",
                            "branch": [
                                "when": ["of": ["ref": "word"], "is": "hey"],
                                "then": ["result": "matched"],
                                "else": ["result": "missed"]
                            ]
                        ],
                        ["var": "walked", "value": 0],
                        [
                            "id": "sized",
                            "each": [
                                "in": ["ref": "names"],
                                "body": [
                                    [
                                        "set": "walked",
                                        "call": [
                                            "of": ["ref": "walked"],
                                            "procedure": "plus",
                                            "arguments": ["value": ["ref": "sized.item.count"]]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        [
                            "id": "line",
                            "value": [
                                "format": "${word}/${pick}",
                                "with": ["word": ["ref": "word"], "pick": ["ref": "pick"]]
                            ]
                        ]
                    ],
                    "result": [
                        "picked": ["ref": "pick"],
                        "sizes": ["ref": "walked"],
                        "line": ["ref": "line"]
                    ]
                ]
            ]
        ]
        let arguments: [String: Value] = [
            "names": .array([.string("a"), .string("bb")]),
            "word": .string("hey")
        ]

        let original = try loader.load(document)
        let travelled = try loader.load(try sut.value(of: original))

        // When
        let before = try await run(original, arguments: arguments)
        let after = try await run(travelled, arguments: arguments)

        // Then
        #expect(before == after)
        #expect(before["picked"] == .string("matched"))
        #expect(before["sizes"] == .int(3))
        #expect(before["line"] == .string("hey/matched"))
    }

    @Test("a spelling is written back as the words it stood for")
    func aSpellingIsWrittenPlainly() throws {
        // Given — `{ of: x, is: y }` is a spelling, and what it means is a
        // message. Writing keeps the meaning and drops the spelling, which is
        // the whole reason the layers are worth separating.
        let module = try loader.loadProcedure([
            "parameters": ["word": "string"],
            "body": [
                [
                    "id": "pick",
                    "branch": [
                        "when": ["of": ["ref": "word"], "is": "hey"],
                        "then": ["result": "matched"]
                    ]
                ]
            ]
        ])

        // When
        let written = try sut.value(of: module)

        // Then
        guard
            case let .array(body)? = written["procedures"]?["entry"]?["body"],
            let message = body.first?["branch"]?["when"]?["call"]
        else {
            Issue.record("a branch is written with a condition under `when`")

            return
        }

        // The word by its full name, since that is what the spelling reached —
        // writing the bare one would put a name in the document that a module
        // declaring its own `equal` could quietly take over.
        #expect(message["procedure"] == .string(SpellingRegistry.standard.word(for: "is") ?? "is"))
        #expect(message["of"]?["ref"] == .string("word"))
        #expect(message["arguments"]?["value"] == .string("hey"))
    }

    @Test("data that would read as a form is written as data")
    func dataThatLooksLikeAFormIsQuoted() throws {
        // Given — a payload with a field called `ref` is not a reference, and
        // writing it bare would make a document that loads into something else
        let module = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "payload",
                            expression: .literal(.object(["ref": .string("not-a-path")]))
                        )
                    ]
                )
            ]
        )

        // When
        let written = try sut.value(of: module)
        let read = try loader.load(written)

        // Then
        guard
            case let .body(block) = read.procedures["entry"]?.implementation,
            case let .literal(carried) = block.body.first?.expression
        else {
            Issue.record("a quoted payload is a literal")

            return
        }

        #expect(carried == .object(["ref": .string("not-a-path")]))
    }

    @Test("a notation that gave up a word cannot write what it said")
    func aDroppedWordCannotBeWritten() throws {
        // Given — the registry is what a notation *is*, so a shape whose word it
        // no longer registers is a shape it can no longer write. Answering with
        // the built-in spelling would put a key in the document that reading it
        // back through this same notation would refuse.
        let module = try loader.loadProcedure([
            "body": [
                [
                    "id": "walked",
                    "loop": [
                        "where": false,
                        "body": [["id": "step", "value": 1]]
                    ]
                ]
            ]
        ])
        let narrowed = Writer(registry: ConstructRegistry.standard.removing(LoopForm.key))

        // When / Then
        #expect(throws: WritingError.self) {
            try narrowed.value(of: module)
        }

        // And the same program through a notation that kept the word is fine
        #expect(throws: Never.self) {
            try sut.value(of: module)
        }
    }

    @Test("a construct binding a name its statement did not give has no document")
    func aMisnamedBindingHasNoDocument() throws {
        // Given — a document cannot write this, because the name a loop binds is
        // the name of the statement it is written as. A caller building the
        // language's shapes directly is under no such obligation, so this is
        // reachable and says so rather than writing a document that would load
        // into something else.
        let module = Module(
            procedures: [
                "entry": Procedure(
                    body: [
                        Statement(
                            id: "walked",
                            expression: .loop(
                                while: .literal(.bool(false)),
                                body: Block(body: [Statement(id: "step", expression: .literal(.int(1)))]),
                                round: "somethingElse"
                            )
                        )
                    ]
                )
            ]
        )

        // When / Then
        #expect {
            try sut.value(of: module)
        } throws: { error in
            "\(error)".contains("binds 'somethingElse' inside 'walked'")
        }
    }

    @Test("a word backed by native code has no document")
    func nativeCodeHasNoDocument() throws {
        // Given — what a caller brings is declared where the run is assembled,
        // not carried in the program. Writing its name alone would make a
        // document that loads into a body nobody wrote.
        let module = Module(procedures: Module.logic.procedures)

        // When / Then
        #expect(throws: WritingError.self) {
            try sut.value(of: module)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Every key anywhere in a document. A spelling is a word, and a word could
    // be written at any depth, so asking whether one survived is asking about
    // the whole of it.
    private static func keys(in value: Value) -> Set<String> {
        switch value {
        case let .array(elements):
            return elements.reduce(into: Set()) { found, element in
                found.formUnion(keys(in: element))
            }

        case let .object(fields):
            return fields.reduce(into: Set(fields.keys)) { found, field in
                found.formUnion(keys(in: field.value))
            }

        default:
            return []
        }
    }

    // Programs built rather than parsed. What they have in common is that no
    // reader made them, so nothing has already forced them into the shapes a
    // document happens to have — which is exactly where a writer goes wrong.
    private static let assembled: [Module] = [
        // Messages nested inside other expressions, deeper than a document's
        // fixed shapes would ever place them
        Module(
            name: "nested",
            procedures: [
                entryName: Procedure(
                    signature: Signature(parameters: ["word": Parameter(type: .string)]),
                    body: [
                        Statement(
                            id: "joined",
                            expression: .dispatch(
                                Dispatch(
                                    receiver: .array([
                                        .dispatch(
                                            Dispatch(
                                                receiver: .reference([.key("word")]),
                                                selector: "text"
                                            )
                                        ),
                                        .literal(.string("!"))
                                    ]),
                                    selector: "joined"
                                )
                            )
                        ),
                        Statement(
                            id: "held",
                            expression: .record([
                                "line": .reference([.key("joined")]),
                                "size": .dispatch(
                                    Dispatch(
                                        receiver: .reference([.key("word")]),
                                        selector: "count"
                                    )
                                )
                            ])
                        )
                    ],
                    result: .reference([.key("held")])
                )
            ]
        ),
        // Data that would read as a form, quoted, and a variable written twice
        Module(
            procedures: [
                entryName: Procedure(
                    body: [
                        Statement(
                            id: "payload",
                            expression: .literal(
                                .object(["ref": .string("not-a-path"), "deep": .array([
                                    .object(["value": .int(1)])
                                ])])
                            )
                        ),
                        Statement(id: "count", binding: .variable, expression: .literal(.int(0))),
                        Statement(id: "count", binding: .assignment, expression: .literal(.int(1)))
                    ],
                    result: .reference([.key("payload")])
                )
            ]
        )
    ]

    // The document format, written out. Every slot the language has appears
    // here exactly once, in the shapes that stand one to one with it — no
    // spelling stands in for anything.
    //
    // It is a fixture and also the closest thing to a statement of what a
    // document *is*. Something reading this from another language would need to
    // understand exactly what is written here and nothing else.
    private static let canonical: Value = [
        "warp": 1,
        "needs": ["plus", "std.logic.notEqual"],
        "name": "canonical",
        "description": "one of every shape",
        "types": ["Task": ["done": "bool", "id": "string"]],
        "const": ["limit": 10],
        "procedures": [
            "entry": [
                "description": "every construct, once",
                "parameters": [
                    "names": "array<string>",
                    "word": ["type": "string", "default": "hey", "hint": "what to match"],
                    "kind": ["type": "string", "oneOf": ["a", "b"]]
                ],
                "returns": "object<any>",
                "body": [
                    ["id": "list", "value": [1, 2, 3]],
                    ["id": "pair", "value": ["a": ["ref": "word"], "b": 2]],
                    ["id": "quoted", "value": ["value": ["ref": "not-a-path"]]],
                    ["var": "seen", "value": 0],
                    ["id": "indexed", "value": ["ref": "names[0]"]],
                    ["id": "computed", "value": ["ref": "names[seen].count"]],
                    [
                        "id": "walked",
                        "loop": [
                            "where": [
                                "call": [
                                    "procedure": "std.logic.notEqual",
                                    "of": ["ref": "seen"],
                                    "arguments": ["value": 3]
                                ]
                            ],
                            "body": [
                                [
                                    "set": "seen",
                                    "call": [
                                        "procedure": "plus",
                                        "of": ["ref": "seen"],
                                        "arguments": ["value": 1]
                                    ]
                                ]
                            ],
                            "result": ["ref": "seen"]
                        ]
                    ],
                    [
                        "id": "pick",
                        "branch": [
                            "when": ["ref": "kind"],
                            "then": [
                                "body": [["id": "said", "value": "yes"]],
                                "result": ["ref": "said"]
                            ],
                            "else": ["result": "no"]
                        ]
                    ],
                    [
                        "id": "mapped",
                        "each": [
                            "in": ["ref": "names"],
                            "body": [["id": "one", "value": ["ref": "mapped.item"]]]
                        ]
                    ],
                    [
                        "id": "tried",
                        "attempt": [
                            "body": [["id": "risky", "value": 1]],
                            "result": ["ref": "risky"],
                            "rescue": [
                                "body": [["id": "instead", "value": 0]],
                                "result": ["ref": "instead"]
                            ]
                        ]
                    ],
                    ["id": "grouped", "group": ["body": [["id": "inner", "value": 1]]]],
                    [
                        "id": "called",
                        "invoke": [
                            "procedure": [
                                "closure": ["parameters": ["n": "int"], "result": ["ref": "n"]]
                            ],
                            "arguments": ["n": 1]
                        ]
                    ]
                ],
                "result": ["result": ["ref": "pick"]]
            ],
            "typed": [
                "receiver": "of",
                "parameters": [
                    "of": "string",
                    "how": [
                        "type": [
                            "pure procedure": [
                                "receiver": "it",
                                "parameters": ["it": "int"],
                                "returns": "bool"
                            ]
                        ]
                    ],
                    "anything": "procedure",
                    "hole": "some Element",
                    "shaped": ["type": ["done": "bool", "id": "string"]]
                ],
                "returns": "never",
                "result": ["ref": "of"]
            ]
        ]
    ]

    // One document per shape the language has, written the way a document
    // usually is — spellings and all, since what comes out the far side is the
    // thing under test.
    static let corpus: [Value] = [
        // Literals, references, records, arrays and quoting
        [
            "name": "plain",
            "description": "the shapes that need no name",
            "types": ["Task": ["id": "string", "done": "bool"]],
            "const": ["limit": 10],
            "procedures": [
                "entry": [
                    "parameters": [
                        "word": "string",
                        "counted": ["type": "int", "default": 1, "hint": "how many"],
                        "kind": ["type": "string", "oneOf": ["a", "b"]]
                    ],
                    "returns": "object<any>",
                    "body": [
                        ["id": "list", "value": [1, 2, 3]],
                        ["id": "pair", "value": ["a": ["ref": "word"], "b": 2]],
                        ["id": "quoted", "value": ["value": ["ref": "literal-text"]]],
                        ["var": "count", "value": ["ref": "counted"]],
                        ["set": "count", "value": 2]
                    ],
                    "result": ["result": ["ref": "pair"]]
                ]
            ]
        ],
        // Branch, group and the condition spellings
        [
            "procedures": [
                "entry": [
                    "parameters": ["word": "string", "ready": "bool"],
                    "body": [
                        [
                            "id": "pick",
                            "branch": [
                                "when": [
                                    "all_of": [
                                        ["of": ["ref": "word"], "is": "hey"],
                                        ["not": ["present": ["ref": "ready"]]]
                                    ]
                                ],
                                "then": [
                                    "body": [["id": "said", "value": "yes"]],
                                    "result": ["ref": "said"]
                                ],
                                "else": ["result": "no"]
                            ]
                        ],
                        ["id": "grouped", "group": ["body": [["id": "inner", "value": 1]]]]
                    ],
                    "result": ["result": ["ref": "pick"]]
                ]
            ]
        ],
        // Loop, each, attempt
        [
            "procedures": [
                "entry": [
                    "parameters": ["names": "array<string>"],
                    "body": [
                        ["var": "seen", "value": 0],
                        [
                            "id": "walked",
                            "loop": [
                                "where": ["of": ["ref": "seen"], "is_not": 3],
                                    "body": [
                                    [
                                        "set": "seen",
                                        "call": [
                                            "procedure": "plus",
                                            "of": ["ref": "seen"],
                                            "arguments": ["value": 1]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        [
                            "id": "mapped",
                            "each": [
                                "in": ["ref": "names"],
                                "body": [["id": "one", "value": ["ref": "mapped.item"]]]
                            ]
                        ],
                        [
                            "id": "tried",
                            "attempt": [
                                "body": [["id": "risky", "fail": true]],
                                "result": ["ref": "risky"],
                                "rescue": ["result": "recovered"]
                            ]
                        ]
                    ],
                    "result": ["result": ["ref": "tried"]]
                ]
            ]
        ],
        // Leaving early, all three ways and both spellings of a target
        [
            "procedures": [
                "entry": [
                    "parameters": ["names": "array<string>"],
                    "returns": "any",
                    "body": [
                        [
                            "id": "outer",
                            "loop": [
                                "where": false,
                                "body": [
                                    [
                                        "id": "walked",
                                        "each": [
                                            "in": ["ref": "names"],
                                            "body": [
                                                [
                                                    "branch": [
                                                        "when": true,
                                                        "then": [
                                                            "body": [
                                                                [
                                                                    "continue": Value.null
                                                                ]
                                                            ]
                                                        ],
                                                        "else": [
                                                            "body": [
                                                                ["break": "outer"]
                                                            ]
                                                        ]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        ["return": ["ref": "outer"]]
                    ]
                ]
            ]
        ],
        // Messages: receivers, carried bodies, closures, invocation, templates
        [
            "procedures": [
                "entry": [
                    "parameters": ["word": "string", "names": "array<string>"],
                    "body": [
                        ["id": "shouted", "call": ["procedure": "shout", "of": ["ref": "word"]]],
                        [
                            "id": "kept",
                            "call": [
                                "procedure": "filter",
                                "of": ["ref": "names"],
                                "arguments": [
                                    "by": [
                                        "closure": [
                                            "parameters": ["item": "string"],
                                            "returns": "bool",
                                            "result": [
                                                "call": [
                                                    "procedure": "notEqual",
                                                    "of": ["ref": "item"],
                                                    "arguments": ["value": ""]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        [
                            "id": "called",
                            "invoke": [
                                "procedure": [
                                    "closure": ["parameters": ["n": "int"], "result": ["ref": "n"]]
                                ],
                                "arguments": ["n": 1]
                            ]
                        ],
                        [
                            "id": "line",
                            "value": ["format": "${word}!", "with": ["word": ["ref": "word"]]]
                        ]
                    ],
                    "result": ["result": ["ref": "line"]]
                ],
                "shout": [
                    "receiver": "of",
                    "parameters": ["of": "string"],
                    "returns": "string",
                    "result": ["ref": "of"]
                ],
                "typed": [
                    "parameters": [
                        "how": ["type": ["pure procedure": ["parameters": ["it": "int"], "returns": "bool"]]],
                        "anything": ["type": "procedure"],
                        "hole": "some Element"
                    ],
                    "returns": "never",
                    "result": ["ref": "anything"]
                ]
            ]
        ]
    ]
}
