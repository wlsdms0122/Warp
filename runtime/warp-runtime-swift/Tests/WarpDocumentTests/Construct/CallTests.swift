//
//  CallTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// `call:` names a symbol, never a document. Naming the document would write a
// linkage fact into the call site, which is the one thing dispatch decided an
// author should never have to write.
@Suite
struct CallTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("the callee signature settles inputs at the call boundary")
    func calleeSignatureSettlesInputs() async throws {
        // Given
        let sut = try loader.load([
            "procedures": [
                "caller": [
                    "body": [
                        [
                            "id": "call",
                            "call": ["procedure": "callee", "arguments": ["base": 41]]
                        ]
                    ],
                    "result": ["result": ["ref": "call.pair"]]
                ],
                "callee": [
                    "parameters": ["base": "int", "bump": ["type": "int", "default": 1]],
                    "body": [
                        [
                            "id": "echo",
                            "value": ["base": ["ref": "base"], "bump": ["ref": "bump"]]
                        ]
                    ],
                    "result": ["pair": ["ref": "echo"]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut, entry: "caller")

        // Then — the omitted `bump` settled to its default at the callee boundary
        #expect(outputs["result"] == .object(["base": .int(41), "bump": .int(1)]))
    }

    @Test("a constant argument violating the callee signature is rejected at link")
    func signatureViolationRejectsCall() throws {
        // Given
        let sut = try loader.load([
            "procedures": [
                "caller": [
                    "body": [
                        [
                            "id": "call",
                            "call": ["procedure": "callee", "arguments": ["base": "not-a-number"]]
                        ]
                    ]
                ],
                "callee": [
                    "parameters": ["base": "int"],
                    "body": [["id": "echo", "value": ["ref": "base"]]]
                ]
            ]
        ])

        // When / Then — nothing runs: the argument is a constant, so its type is
        // knowable before the run and the refusal happens there
        #expect(throws: LinkError.self) {
            try loader.language.link([sut], entry: "caller")
        }
    }

    @Test("a call names a procedure and not the module that declares it")
    func callNamesASymbol() async throws {
        // Given — the callee lives in a module the caller never mentions
        let caller = try loader.load([
            "procedures": [
                "caller": [
                    "body": [["id": "call", "call": ["procedure": "greet"]]],
                    "result": ["result": ["ref": "call.said"]]
                ]
            ]
        ])
        let elsewhere = try loader.load([
            "name": "some-other-file",
            "procedures": [
                "greet": [
                    "body": [["id": "word", "value": "hello"]],
                    "result": ["said": ["ref": "word"]]
                ]
            ]
        ])

        // When
        let outputs = try await run([caller, elsewhere], entry: "caller")

        // Then
        #expect(outputs["result"] == .string("hello"))
    }

    @Test("a call writes what it is sent to")
    func callWritesItsReceiver() async throws {
        // Given — `call` reaches a receiver the same way a spelling does, so a
        // document is not forced through `x.shout` to send to one
        let sut = try loader.load([
            "procedures": [
                "entry": [
                    "parameters": ["word": "string"],
                    "body": [
                        [
                            "id": "said",
                            "call": ["procedure": "shout", "of": ["ref": "word"]]
                        ]
                    ],
                    "result": ["result": ["ref": "said"]]
                ],
                "shout": [
                    "receiver": "of",
                    "parameters": ["of": "string"],
                    "returns": "string",
                    "body": [],
                    "result": ["format": "${of}!", "with": ["of": ["ref": "of"]]]
                ]
            ]
        ])

        // When
        let outputs = try await run(sut, arguments: ["word": .string("hey")])

        // Then
        #expect(outputs["result"] == .string("hey!"))
    }

    @Test("a call carries values only — a blocks key has no meaning to refuse quietly")
    func aBlocksKeyIsRefusedAtDecode() {
        // Given — a body a word is to run travels as a closure argument, so
        // `blocks:` names nothing. An unknown key is refused where it is
        // written rather than dropped.
        let sut: Value = [
            "procedures": [
                "entry": [
                    "body": [
                        [
                            "id": "walked",
                            "call": [
                                "procedure": "helper",
                                "blocks": ["body": ["body": [["id": "step", "value": 1]]]]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        // When / Then
        #expect {
            try loader.load(sut)
        } throws: { error in
            "\(error)".contains("blocks")
        }
    }

    @Test("runaway recursive calls end by caller cancellation")
    func recursiveCallStopsOnCancellation() async throws {
        // Given — the kernel carries no recursion guard (a reappearing name is not
        // a cycle oracle); runaway calls end by caller cancellation, which must
        // propagate through the call chain
        let module = try loader.load([
            "procedures": ["loopy": ["body": [["id": "again", "call": ["procedure": "loopy"]]]]]
        ])
        let image = try loader.language.link([module], entry: "loopy")
        let sut = loader.language.makeExecutor()

        // When
        let task = Task {
            try await sut.run(image)
        }

        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        // Then
        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }
}
