//
//  VariableNotationTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// How a document spells a binding — `id:`, `var:`, `set:`. What a binding
// *means* is the language's, and `WarpTests` asks it there.
@Suite
struct VariableNotationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a write inside a block outlives the block")
    func assignmentOutlivesItsBlock() async throws {
        // Given — the one thing a binding cannot do: a branch that ran changes
        // what an enclosing name means afterwards
        let sut = try loader.loadProcedure([
            "parameters": ["kind": "string"],
            "body": [
                ["var": "verdict", "value": "untouched"],
                [
                    "id": "gate",
                    "branch": [
                        "when": ["of": ["ref": "kind"], "is": "a"],
                        "then": ["body": [["set": "verdict", "value": "touched"]]]
                    ]
                ]
            ],
            "result": ["result": ["ref": "verdict"]]
        ])

        // When
        let outputs = try await run(sut, arguments: ["kind": .string("a")])

        // Then
        #expect(outputs["result"] == .string("touched"))
    }

    @Test("a branch that did not run changes nothing")
    func untakenBranchLeavesVariableAlone() async throws {
        // Given
        let sut = try loader.loadProcedure([
            "parameters": ["kind": "string"],
            "body": [
                ["var": "verdict", "value": "untouched"],
                [
                    "id": "gate",
                    "branch": [
                        "when": ["of": ["ref": "kind"], "is": "a"],
                        "then": ["body": [["set": "verdict", "value": "touched"]]]
                    ]
                ]
            ],
            "result": ["result": ["ref": "verdict"]]
        ])

        // When
        let outputs = try await run(sut, arguments: ["kind": .string("b")])

        // Then
        #expect(outputs["result"] == .string("untouched"))
    }

    @Test("a variable declared inside a block does not escape it")
    func innerVariableDoesNotEscape() throws {
        // Given — the box is shared, but which names exist is not: `var` inside
        // a branch introduces a name that dies with the branch
        let fixture: Value = [
            "body": [
                ["id": "seed", "value": 1],
                [
                    "id": "gate",
                    "branch": [
                        "when": ["present": ["ref": "seed"]],
                        "then": ["body": [["var": "inner", "value": 1]]]
                    ]
                ]
            ],
            "result": ["result": ["ref": "inner"]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a var inside a block shadows the outer one instead of writing it")
    func innerVariableShadowsOuter() async throws {
        // Given — `var` always introduces, so the inner name is a different
        // name with a box of its own. Writing the outer one is `set`.
        let sut = try loader.loadProcedure([
            "body": [
                ["var": "verdict", "value": "outer"],
                [
                    "id": "gate",
                    "branch": [
                        "when": ["present": ["ref": "verdict"]],
                        "then": ["body": [["var": "verdict", "value": "inner"]]]
                    ]
                ]
            ],
            "result": ["result": ["ref": "verdict"]]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .string("outer"))
    }

    @Test("writing a fixed name is rejected at load")
    func assigningConstantRejected() throws {
        // Given — `id` means the name is fixed, and the refusal says which of
        // the two mistakes this is
        let fixture: Value = [
            "body": [["id": "verdict", "value": "first"], ["set": "verdict", "value": "second"]],
            "result": ["result": ["ref": "verdict"]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("writing a name nothing declared is rejected at load")
    func assigningUndeclaredRejected() throws {
        // Given
        let fixture: Value = [
            "body": [["set": "verdict", "value": "second"]],
            "result": ["result": ["ref": "verdict"]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a closure may not write a variable from outside")
    func closureCannotWriteOuterVariable() throws {
        // Given — a closure may run beside another or long after this body, so
        // a write out of it is the one ordering nothing can supply. Refused at
        // load rather than raced at run time.
        let fixture: Value = [
            "body": [
                ["var": "tally", "value": 0],
                [
                    "id": "later",
                    "value": [
                        "closure": [
                            "body": [["set": "tally", "value": 1]],
                            "result": ["ref": "tally"]
                        ]
                    ]
                ]
            ],
            "result": ["result": ["ref": "tally"]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a closure may declare and write its own variable")
    func closureOwnsItsVariables() async throws {
        // Given — what is forbidden is reaching outward, not variables
        let sut = try loader.loadProcedure([
            "body": [
                [
                    "id": "both",
                    "call": [
                        "procedure": "all",
                        "of": [
                            "left": [
                                "closure": [
                                    "body": [
                                        ["var": "tally", "value": 0],
                                        ["set": "tally", "value": 1]
                                    ],
                                    "result": ["ref": "tally"]
                                ]
                            ],
                            "right": ["closure": ["result": 2]]
                        ]
                    ]
                ]
            ],
            "result": ["result": ["ref": "both.left"]]
        ])

        // When
        let outputs = try await run(sut)

        // Then
        #expect(outputs["result"] == .int(1))
    }

    @Test("a step naming itself twice is rejected at load")
    func doubleNameKeyRejected() throws {
        // Given — `id`/`var`/`set` are one slot spelled three ways, not three
        // keys that may combine
        let fixture: Value = ["body": [["id": "verdict", "var": "verdict", "value": "x"]]]

        // When / Then
        #expect(throws: DecodingError.self) {
            try loader.loadProcedure(fixture)
        }
    }
}
