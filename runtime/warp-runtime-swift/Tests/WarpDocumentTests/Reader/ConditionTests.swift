//
//  ConditionTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

@Suite
struct ConditionTests {
    // MARK: - Property
    private let scope = Scope(bindings: ["kind": .string("a"), "n": .int(3), "none": .null])

    // MARK: - Initializer
    // MARK: - Test
    @Test("predicates evaluate against scope values")
    func predicatesEvaluateAgainstScope() throws {
        // Given
        let sut = Resolver(scope: scope, derivations: Module.standard.procedures)

        // Then
        #expect(try sut.evaluate(
            equals(.reference(path("kind")), .literal(.string("a")))
        ))
        #expect(try sut.evaluate(
            differs(.reference(path("kind")), .literal(.string("b")))
        ))
        #expect(try sut.evaluate(
            .dispatch(Dispatch(receiver: .array([.literal(.int(3)), .literal(.int(4))]), selector: "contains", arguments: ["value": .reference(path("n"))]))
        ))
        #expect(try sut.evaluate(
            differs(.reference(path("n")), .literal(.null))
        ))
        #expect(try !sut.evaluate(
            differs(.reference(path("none")), .literal(.null))
        ))
        #expect(try !sut.evaluate(
            differs(.reference(path("gone")), .literal(.null))
        ))
    }

    @Test("both sides of a predicate are expressions")
    func bothSidesAreExpressions() throws {
        // Given
        let sut = Resolver(
            scope: Scope(bindings: [
            "left": .string("same"),
            "right": .string("same"),
            "candidates": .array([.string("same"), .string("other")])
        ]),
            derivations: Module.standard.procedures
        )

        // Then — a reference compares against another reference
        #expect(try sut.evaluate(
            equals(.reference(path("left")), .reference(path("right")))
        ))

        // And one_of can draw its candidates from the scope
        #expect(try sut.evaluate(
            .dispatch(Dispatch(receiver: .reference(path("candidates")), selector: "contains", arguments: ["value": .reference(path("left"))]))
        ))
    }

    @Test("numeric equality crosses int and double")
    func numericEqualityCrossesIntAndDouble() throws {
        // Given
        let sut = Resolver(scope: scope, derivations: Module.standard.procedures)

        // Then
        #expect(try sut.evaluate(
            equals(.reference(path("n")), .literal(.double(3.0)))
        ))
    }

    @Test("combinators compose nested conditions")
    func combinatorsCompose() throws {
        // Given
        let sut = Resolver(scope: scope, derivations: Module.standard.procedures)
        let condition = every(
            equals(.reference(path("kind")), .literal(.string("a"))),
            negating(equals(.reference(path("n")), .literal(.int(4))))
            )

        // Then
        #expect(try sut.evaluate(condition))
    }

    @Test("text atoms evaluate on strings; asking a number is unfit")
    func textAtomsEvaluateOnStrings() throws {
        // Given
        let sut = Resolver(
            scope: Scope(bindings: [
            "title": .string("hello, spec"),
            "tags": .array([.string("a"), .string("b")]),
            "n": .int(3)
        ]),
            derivations: Module.standard.procedures
        )

        // Then
        #expect(try sut.evaluate(
            .dispatch(Dispatch(receiver: .reference(path("title")), selector: "contains", arguments: ["value": .literal(.string("spec"))]))
        ))
        #expect(try sut.evaluate(
            .dispatch(Dispatch(receiver: .reference(path("tags")), selector: "contains", arguments: ["value": .literal(.string("b"))]))
        ))
        #expect(try sut.evaluate(
            .dispatch(Dispatch(receiver: .reference(path("title")), selector: "startsWith", arguments: ["value": .literal(.string("hello"))]))
        ))
        #expect(try sut.evaluate(
            .dispatch(Dispatch(receiver: .reference(path("title")), selector: "regex", arguments: ["value": .literal(.string("sp.c$"))]))
        ))
        #expect(try !sut.evaluate(
            .dispatch(Dispatch(receiver: .reference(path("gone")), selector: "contains", arguments: ["value": .literal(.string("x"))]))
        ))

        // A text atom asking a number is shape misuse, not a false answer
        #expect(throws: ReferenceUnfit.self) {
            try sut.evaluate(
                .dispatch(Dispatch(receiver: .reference(path("n")), selector: "startsWith", arguments: ["value": .literal(.string("3"))]))
            )
        }
    }

    @Test("an invalid regex pattern is rejected at link")
    func invalidRegexRejectedAtLink() {
        // Given
        let fixture: Value = [
            "parameters": ["title": "string"],
            "body": [
                [
                    "id": "gated",
                    "branch": [
                        "when": ["of": ["ref": "title"], "regex": "[unclosed"],
                        "then": ["body": [["id": "taken", "value": "x"]]]
                    ]
                ]
            ]
        ]

        // When / Then — the pattern compiles before any run. Checking it while
        // decoding would make the notation hold the vocabulary; it is checked
        // where names resolve.
        #expect(throws: LinkError.self) {
            try Loader.testing.language.link(
                [try Loader.testing.loadProcedure(fixture)] + Module.standard,
                entry: entryName
            )
        }
    }

    @Test("shape misuse in a condition is unfit, not false")
    func conditionShapeMisuseThrowsUnfit() {
        // Given
        let sut = Resolver(scope: scope, derivations: Module.standard.procedures)

        // When / Then — a typo'd drill must not silently read as false
        #expect(throws: ReferenceUnfit.self) {
            try sut.evaluate(
                differs(.reference(path("n.field")), .literal(.null))
            )
        }
    }

    @Test("two operator keys in one condition are rejected")
    func doubleOperatorKeysRejected() {
        // Given
        let fixture: Value = [
            "parameters": ["k": "string"],
            "body": [
                [
                    "id": "gated",
                    "branch": [
                        "when": ["of": ["ref": "k"], "is": "a", "is_not": "b"],
                        "then": ["body": [["id": "taken", "value": "x"]]]
                    ]
                ]
            ]
        ]

        // When / Then — first-wins would silently drop the second predicate
        #expect(throws: DecodingError.self) {
            try Loader.testing.loadProcedure(fixture)
        }
    }

    @Test("a binary operator without a subject is rejected")
    func binaryOperatorWithoutSubjectRejected() {
        // Given
        let fixture: Value = [
            "parameters": ["k": "string"],
            "body": [
                [
                    "id": "gated",
                    "branch": [
                        "when": ["is": "a"],
                        "then": ["body": [["id": "taken", "value": "x"]]]
                    ]
                ]
            ]
        ]

        // When / Then — is compares two sides; a lone operand names neither
        #expect(throws: DecodingError.self) {
            try Loader.testing.loadProcedure(fixture)
        }
    }

    @Test("present with a subject key is rejected")
    func presentWithSubjectKeyRejected() {
        // Given
        let fixture: Value = [
            "parameters": ["k": "string"],
            "body": [
                [
                    "id": "gated",
                    "branch": [
                        "when": ["of": ["ref": "k"], "present": ["ref": "k"]],
                        "then": ["body": [["id": "taken", "value": "x"]]]
                    ]
                ]
            ]
        ]

        // When / Then — present takes its expression directly, without `of`
        #expect(throws: DecodingError.self) {
            try Loader.testing.loadProcedure(fixture)
        }
    }

    @Test("validation covers both sides of a predicate")
    func validationCoversBothSides() {
        // Given
        let condition = equals(
            .reference(path("left")),
            .reference(path("outer.right"))
            )

        // Then — neither side is skipped
        #expect(validates(condition, visible: ["left", "outer"]))
        #expect(!validates(condition, visible: ["left"]))
        #expect(!validates(condition, visible: ["outer"]))
    }
}
