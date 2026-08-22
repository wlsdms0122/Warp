//
//  ValidationTests.swift
//  WarpTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp

// A document is checked against itself, before anything is resolved. The walk
// is structural, which is what these ask: not whether a particular notation
// rejects a particular text, but what the language considers visible where.
@Suite
struct ValidationTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a name is visible only after the statement that introduced it")
    func namesAreVisibleAfterTheirStatement() {
        // Given
        let forward = [
            Statement(id: "first", expression: reference("second")),
            Statement(id: "second", expression: .literal(.int(1)))
        ]
        let backward = [
            Statement(id: "first", expression: .literal(.int(1))),
            Statement(id: "second", expression: reference("first"))
        ]

        // When / Then
        #expect(!validates(body: forward))
        #expect(validates(body: backward))
    }

    @Test("two statements at one level may not share a name")
    func siblingNamesMustDiffer() {
        // Given
        let sut = [
            Statement(id: "same", expression: .literal(.int(1))),
            Statement(id: "same", expression: .literal(.int(2)))
        ]

        // When / Then
        #expect(!validates(body: sut))
    }


    @Test("a parameter is a name the body may read and may not introduce again")
    func parametersAreVisibleAndDeclared() throws {
        // Given — the signature and the body are one scope, so a name is
        // introduced once
        let readsIt = Procedure(
            signature: Signature(parameters: ["name": Parameter(type: .string)]),
            body: [Statement(id: "greeting", expression: reference("name"))]
        )
        let redeclaresIt = Procedure(
            signature: Signature(parameters: ["name": Parameter(type: .string)]),
            body: [Statement(id: "name", expression: .literal(.string("other")))]
        )

        // When / Then
        try Validator().validate(readsIt)

        #expect(throws: (any Error).self) {
            try Validator().validate(redeclaresIt)
        }
    }

    @Test("a reference must start with a name")
    func referenceMustHaveAHead() {
        // Given
        let sut = Warp.Expression.reference([.index(0)])

        // When / Then
        #expect(!validates(sut))
    }

    @Test("an index reference is checked like any other name")
    func indexReferenceHeadIsChecked() {
        // Given — `items[${cursor}]` reads `cursor`, so a typo in it is the
        // same mistake as a typo anywhere else
        let sut = Warp.Expression.reference(
            [.key("items"), .indexRef([.key("cursor")])]
        )

        // When / Then
        #expect(!validates(sut, visible: ["items"]))
        #expect(validates(sut, visible: ["items", "cursor"]))
    }

    @Test("a template's placeholders resolve against its bindings, not the scope")
    func templatePlaceholdersAreClosed() {
        // Given — only the binding expressions reach outward
        let sut = interpolated(spelling(reference("name")))

        // When / Then
        #expect(validates(sut, visible: ["name"]))
        #expect(!validates(sut, visible: ["who"]))
    }

    @Test("a name nothing declared is visible nowhere")
    func undeclaredNamesAreNotVisible() throws {
        // Given — there is one way a name gets here, and it is being declared.
        // A run's own values arrive as arguments like everything else.
        let read = Procedure(body: [Statement(id: "read", expression: reference("run", "id"))])
        let taken = Procedure(
            signature: Signature(parameters: ["run": Parameter(type: .object(.any))]),
            body: [Statement(id: "read", expression: reference("run", "id"))]
        )

        // When / Then
        #expect(throws: ValidationError.self) {
            try Validator().validate(read)
        }

        try Validator().validate(taken)
    }

    @Test("a result expression is checked against what the body left visible")
    func resultsSeeTheWholeBody() throws {
        // Given
        let sut = Procedure(
            body: [Statement(id: "made", expression: .literal(.int(1)))],
            result: .record(["ok": reference("made"), "bad": reference("never")])
        )

        // When / Then
        #expect(throws: ValidationError.self) {
            try Validator().validate(sut)
        }
    }
}
