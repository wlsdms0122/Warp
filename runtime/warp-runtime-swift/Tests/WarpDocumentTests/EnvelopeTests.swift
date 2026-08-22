//
//  EnvelopeTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// What a document says about itself before anything reads what it says.
//
// Both questions exist only because a program can arrive somewhere that did not
// build it: is this written for a reader like me, and do I have the words it
// calls. A program that stays where it was built has neither question, because
// the thing that built it is the thing that runs it.
//
// And both have to be answerable before it runs. Half-running a program is the
// one outcome worse than refusing it, since what already happened cannot be
// taken back.
@Suite("A document says what it needs before it is read")
struct EnvelopeTests {
    // MARK: - Property
    private let loader = Loader.testing
    private let sut = Writer()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a document written for a later reader is refused")
    func aLaterDocumentIsRefused() {
        // Given — this is the failure the version exists to prevent. Without it
        // a reader meets a shape it does not know, reads what it recognises and
        // ignores the rest, and runs a program nobody wrote.
        #expect {
            try loader.load([
                "warp": .int(Envelope.version + 1),
                "procedures": ["entry": ["result": "hello"]]
            ])
        } throws: { error in
            "\(error)".contains("written for warp")
        }

        // And one written for this reader is read
        #expect(throws: Never.self) {
            try loader.load([
                "warp": .int(Envelope.version),
                "procedures": ["entry": ["result": "hello"]]
            ])
        }
    }

    @Test("a document that says nothing is read as the earliest")
    func silenceMeansTheEarliest() throws {
        // Given — what lets a document written before any of this existed still
        // be read. Refusing one would make the field's arrival a breaking change
        // for every program already written.
        let sut = try loader.load(["procedures": ["entry": ["result": "hello"]]])

        // Then
        #expect(sut.procedures["entry"] != nil)
    }

    @Test("what a document says it needs is what it sends")
    func theManifestIsTheTruth() throws {
        // Given — a caller reads this to decide whether to run the program at
        // all, so a list allowed to drift would be worse than none: it would be
        // trusted and wrong.
        let module = try loader.load([
            "procedures": [
                "entry": [
                    "parameters": ["names": "array<string>"],
                    "body": [
                        [
                            "id": "many",
                            "call": ["procedure": "plus", "of": 1, "arguments": ["value": 2]]
                        ]
                    ],
                    "result": ["ref": "many"]
                ]
            ]
        ])

        // When
        let written = try sut.value(of: module)

        // Then
        #expect(written[Envelope.needsKey] == .array([.string("plus")]))
    }

    @Test("a document that undersells what it needs is refused")
    func anUntruthfulManifestIsRefused() {
        // Given — the whole value of the list is that it can be believed
        #expect {
            try loader.load([
                "needs": [],
                "procedures": [
                    "entry": [
                        "body": [
                            [
                                "id": "sum",
                                "call": ["procedure": "plus", "of": 1, "arguments": ["value": 2]]
                            ]
                        ],
                        "result": ["ref": "sum"]
                    ]
                ]
            ])
        } throws: { error in
            "\(error)".contains("says it needs")
        }
    }

    @Test("a document that oversells what it needs is refused the same way")
    func anOverstatedManifestIsRefused() {
        // Given — the list is the set of what the program sends, not a bound
        // around it: a caller grants from this list, and a word listed but
        // never sent is a grant the program had no use for
        #expect {
            try loader.load([
                "needs": ["plus", "minus"],
                "procedures": [
                    "entry": [
                        "body": [
                            [
                                "id": "sum",
                                "call": ["procedure": "plus", "of": 1, "arguments": ["value": 2]]
                            ]
                        ],
                        "result": ["ref": "sum"]
                    ]
                ]
            ])
        } throws: { error in
            "\(error)".contains("says it needs")
        }
    }

    @Test("a word sent from a constant is needed like any other")
    func constantsSendWordsToo() throws {
        // Given — a constant is an expression, and understating what a program
        // needs is worse than saying nothing: a caller decides from this list
        // what to allow, and would then be refused at the link by a word the
        // list never mentioned.
        let module = try loader.load([
            "const": ["limit": ["call": ["procedure": "plus", "of": 1, "arguments": ["value": 2]]]],
            "procedures": ["entry": ["result": ["ref": "limit"]]]
        ])

        // Then
        #expect(Envelope.needs(of: module) == ["plus"])
    }

    @Test("a document claiming a version that never existed is refused")
    func aVersionBelowTheEarliestIsRefused() {
        // Given — the range is closed at both ends. Below it, a document claims
        // a language that never was.
        #expect(throws: (any Error).self) {
            try loader.load(["warp": 0, "procedures": ["entry": ["result": "hello"]]])
        }
    }

    @Test("being too old to read a document is not the same as the document being wrong")
    func versionIsCheckedBeforeShape() {
        // Given — a later version may add keys, so checking the shape first
        // would turn "I am too old for this" into "this is malformed". The
        // answers differ: one is upgrade me, the other is fix the sender.
        #expect {
            try loader.load([
                "warp": .int(Envelope.version + 1),
                "somethingALaterVersionAdded": "…",
                "procedures": ["entry": ["result": "hello"]]
            ])
        } throws: { error in
            "\(error)".contains("written for warp")
        }
    }

    @Test("a document written for the earliest reader is still read")
    func anEarlierDocumentIsStillRead() throws {
        // Given — the number moved when the language did, and the promise that
        // makes it worth having is that moving it does not lock out what was
        // already written. Backward is a promise; forward is not available to
        // anyone, which is the whole reason the number exists. Nothing has
        // shipped yet, so the two ends of the promise are one number for now.
        let sut = try loader.load([
            "warp": .int(Envelope.earliest),
            "procedures": ["entry": ["result": "hello"]]
        ])

        // Then
        #expect(sut.procedures["entry"] != nil)
    }

    @Test("a word a document declares itself is not something it needs")
    func ownWordsAreNotNeeds() throws {
        // Given — what a document brings with it is not what it asks for
        let module = try loader.load([
            "procedures": [
                "entry": [
                    "body": [["id": "said", "call": ["procedure": "greet"]]],
                    "result": ["ref": "said"]
                ],
                "greet": ["result": "hello"]
            ]
        ])

        // Then
        #expect(Envelope.needs(of: module).isEmpty)
    }

    @Test("what a program can do to anything is what it sends")
    func sendingBoundsWhatAProgramReaches() throws {
        // Given — a path reaches words too, and this is why the list can still be
        // read as the bounds of what a program is allowed to do. `count` here is
        // reached by walking rather than sending, and a path only ever reaches a
        // word that answers without running — so nothing a path reaches can touch
        // anything outside.
        let module = try loader.load([
            "procedures": [
                "entry": [
                    "parameters": ["names": "array<string>"],
                    "body": [["id": "many", "value": ["ref": "names.count"]]],
                    "result": ["ref": "many"]
                ]
            ]
        ])

        // Then
        #expect(Envelope.needs(of: module).isEmpty)

        // And the link still holds it to that — the word has to be there
        #expect(throws: LinkError.self) {
            try loader.language.link([module], entry: entryName)
        }
    }

    @Test("a word sent from anywhere inside is counted")
    func everyCornerIsCounted() throws {
        // Given — a list that missed one would be a list nobody could rely on,
        // so every place a message can be written is walked
        let module = try loader.load([
            "procedures": [
                "entry": [
                    "parameters": ["names": "array<string>"],
                    "body": [
                        [
                            "id": "held",
                            "value": [
                                "closure": ["result": ["call": ["procedure": "inClosure"]]]
                            ]
                        ],
                        [
                            "id": "walked",
                            "each": [
                                "in": ["ref": "names"],
                                "body": [["id": "seen", "call": ["procedure": "inEach"]]]
                            ]
                        ],
                        [
                            "id": "tried",
                            "attempt": [
                                "body": [["id": "risky", "call": ["procedure": "inBody"]]],
                                "result": ["ref": "risky"],
                                "rescue": [
                                    "body": [["id": "back", "call": ["procedure": "inRescue"]]],
                                    "result": ["ref": "back"]
                                ]
                            ]
                        ],
                        [
                            "id": "deep",
                            "value": ["a": [["call": ["procedure": "inNestedData"]]]]
                        ]
                    ],
                    "result": ["ref": "tried"]
                ]
            ]
        ])

        // Then
        #expect(
            Envelope.needs(of: module)
                == ["inClosure", "inEach", "inBody", "inRescue", "inNestedData"]
        )
    }

    // MARK: - Public
    // MARK: - Private
}
