//
//  LoadGateTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

@Suite
struct LoadGateTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("an unknown step key is rejected at load")
    func unknownStepKeyRejected() {
        // Given
        let fixture: Value = ["body": [["id": "broken", "value": "x", "fallbck": "y"]]]

        // When / Then
        #expect(throws: DecodingError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a guard written on the envelope is rejected, because branch is where a guard goes")
    func envelopeGuardRejected() {
        // Given — no language spells a guard as a modifier on a statement.
        // `if x { some() }` is the form, and that is `branch`, so the envelope
        // reads `when:` as the unknown key it is.
        let fixture: Value = [
            "parameters": ["kind": "string"],
            "body": [
                [
                    "id": "only-a",
                    "when": ["of": ["ref": "kind"], "is": "a"],
                    "value": "taken"
                ]
            ]
        ]

        // When / Then
        #expect(throws: DecodingError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a step declaring two actions is rejected")
    func doubleActionStepRejected() {
        // Given
        let fixture: Value = ["body": [["id": "broken", "value": "x", "fail": true]]]

        // When / Then
        #expect(throws: DecodingError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("an unknown reference head is caught at load, not at run")
    func unknownReferenceHeadRejected() {
        // Given — forward references and typos surface at load, not at run
        let fixture: Value = [
            "body": [["id": "early", "value": ["ref": "later"]], ["id": "later", "value": "x"]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("duplicate sibling step ids are rejected")
    func duplicateSiblingIDsRejected() {
        // Given
        let fixture: Value = ["body": [["id": "twin", "value": "x"], ["id": "twin", "value": "y"]]]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a step id colliding with a declared input is rejected")
    func parameterCollisionRejected() {
        // Given — the signature and the body are one scope, so the name the
        // signature introduced cannot be introduced again
        let fixture: Value = [
            "parameters": ["name": ["type": "string"]],
            "body": [["id": "name", "value": "x"]]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("an empty rescue is rejected")
    func emptyRescueRejected() {
        // Given — an attempt whose rescue produces nothing swallows the failure
        // into null without a trace; the honest form is no attempt at all
        let fixture: Value = [
            "body": [
                [
                    "id": "fragile",
                    "attempt": ["body": [["id": "broken", "fail": true]], "rescue": ["body": []]]
                ]
            ]
        ]

        // When / Then
        #expect(throws: DecodingError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a typo in a nested index reference is caught at load")
    func indexReferenceTypoRejected() {
        // Given
        let fixture: Value = [
            "parameters": ["items": "array"],
            "body": [["id": "pick", "value": ["ref": "items[${typoooo}]"]]]
        ]

        // When / Then — nested index refs are part of the reference, not a blind spot
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("an empty index segment is rejected at parse")
    func emptyIndexSegmentRejected() {
        // Given — `[]` is an author mistake, rejected at parse instead of being
        // carried into the model
        let fixture: Value = [
            "parameters": ["items": "array"],
            "body": [["id": "pick", "value": ["ref": "items[]"]]]
        ]

        // When / Then
        #expect(throws: DecodingError.self) {
            try loader.loadProcedure(fixture)
        }
    }

    @Test("a name a run supplies is declared like every other name")
    func runValuesAreDeclared() throws {
        // Given — there is one way a name gets into a body. A value a run
        // supplies arrives as an argument and is written down as one.
        let declared: Value = [
            "parameters": ["run": "object"],
            "body": [["id": "whoami", "value": ["ref": "run.id"]]]
        ]
        let assumed: Value = ["body": [["id": "whoami", "value": ["ref": "run.id"]]]]

        // When / Then
        #expect(throws: Never.self) {
            try loader.loadProcedure(declared)
        }
        #expect(throws: ValidationError.self) {
            try loader.loadProcedure(assumed)
        }
    }

    @Test("runtime data becomes IR through the loader's Value door")
    func valueLowersThroughFrontendDoor() throws {
        // Given — a step array that arrived as data (through a signature) becomes
        // IR via the loader's Value door; the string stays a literal even there
        let carried = Value.array([
            .object(["id": .string("greet"), "value": .string("hello there")])
        ])

        // When
        let statements = try loader.statements(from: carried)

        // Then
        #expect(statements.count == 1)
        #expect(statements[0].id == "greet")
        #expect(statements[0].expression.constantValue == .string("hello there"))
    }

}
