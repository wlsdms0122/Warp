//
//  SignatureTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

@Suite
struct SignatureTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a parameter written without a type declares nothing, and takes anything")
    func untypedParameterDeclaresNothing() throws {
        // Given — `any` would say every shape is welcome; this says nothing at
        // all, and the two are not the same declaration even though neither is
        // checked
        let sut = try Loader.testing.load([
            "name": "notes",
            "procedures": [
                "keep": [
                    "parameters": ["subject": [:], "labelled": "any"],
                    "body": [["id": "done", "value": ["ref": "subject"]]]
                ]
            ]
        ])

        // Then
        let signature = try #require(sut.procedures["keep"]).signature

        #expect(signature.parameters["subject"]?.type == nil)
        #expect(signature.parameters["labelled"]?.type == .any)

        // Neither checks, so both take a shape nothing was said about.
        let settled = try signature.settle(["subject": .int(1), "labelled": .int(2)])

        #expect(settled["subject"] == .int(1))
        #expect(settled["labelled"] == .int(2))
    }

    @Test("a procedure written without a return type declares nothing")
    func untypedReturnDeclaresNothing() throws {
        // Given
        let sut = try Loader.testing.load([
            "name": "notes",
            "procedures": [
                "quiet": ["body": [["id": "done", "value": "end"]]],
                "loud": ["returns": "any", "body": [["id": "done", "value": "end"]]]
            ]
        ])

        // Then
        #expect(try #require(sut.procedures["quiet"]).signature.returns == nil)
        #expect(try #require(sut.procedures["loud"]).signature.returns == .any)
    }

    @Test("an omitted input fills from its default")
    func omittedInputFillsDefault() throws {
        // Given
        let sut = Signature(parameters: [
            "mode": Parameter(type: .string, default: .string("fast"))
        ])

        // When
        let settled = try sut.settle([:])

        // Then
        #expect(settled["mode"] == .string("fast"))
    }

    @Test("a missing required input is rejected")
    func missingRequiredInputRejected() {
        // Given
        let sut = Signature(parameters: ["name": Parameter(type: .string)])

        // When / Then
        #expect(throws: ArgumentError.self) {
            try sut.settle([:])
        }
    }

    @Test("a type mismatch is rejected")
    func typeMismatchRejected() {
        // Given
        let sut = Signature(parameters: ["count": Parameter(type: .int)])

        // When / Then
        #expect(throws: ArgumentError.self) {
            try sut.settle(["count": .string("three")])
        }
    }

    @Test("a fraction is not a whole number, whatever it is worth")
    func aFractionDoesNotNarrow() throws {
        // Given — a slot asking for a whole number. Taking a fraction that
        // happened to be whole would make the answer to "does this fit" depend
        // on the value rather than the type: `3.0` accepted where `3.5` is
        // refused, by a declaration that names neither.
        let sut = Signature(parameters: ["count": Parameter(type: .int)])

        // When / Then
        #expect(throws: ArgumentError.self) {
            try sut.settle(["count": .double(3)])
        }

        // And the conversion that loses nothing still happens
        let widened = Signature(parameters: ["ratio": Parameter(type: .double)])

        #expect(try widened.settle(["ratio": .int(3)])["ratio"] == .double(3))
    }

    @Test("an undeclared input name is rejected")
    func undeclaredInputRejected() {
        // Given
        let sut = Signature(parameters: ["a": Parameter(type: .string)])

        // When / Then — an extra name is a typo surfaced, not a value smuggled in
        #expect(throws: ArgumentError.self) {
            try sut.settle(["a": .string("x"), "sneaky": .int(9)])
        }
    }

    @Test("a value outside oneOf is rejected")
    func valueOutsideOneOfRejected() {
        // Given
        let sut = Signature(parameters: [
            "mode": Parameter(type: .string, oneOf: ["fast", "slow"])
        ])

        // When / Then
        #expect(throws: ArgumentError.self) {
            try sut.settle(["mode": .string("medium")])
        }
    }

    @Test("a default failing its own gate is judged at the link")
    func defaultFailingOwnGateIsALinkRefusal() throws {
        // Given — the declaration is judged where declared type names resolve,
        // so the document reads fine and the link refuses it
        let spec = try Loader.testing.loadProcedure([
            "parameters": [
                "mode": ["type": "string", "oneOf": ["fast", "slow"], "default": "medium"]
            ],
            "body": [["id": "noop", "value": "ok"]]
        ])

        // When / Then
        #expect(throws: LinkError.self) {
            try Language().link([spec] + Module.standard, entry: entryName)
        }
    }

    @Test("a default is stored as written, and arrives settled")
    func suppliedDefaultArrivesSettled() async throws {
        // Given — the document holds what was written; taking the default walks
        // the same gate an argument does, so the body still reads the declared
        // representation
        let spec = try Loader.testing.loadProcedure([
            "parameters": ["ratio": ["type": "double", "default": 3]],
            "body": [["id": "echo", "value": ["ref": "ratio"]]],
            "result": ["result": ["ref": "echo"]]
        ])

        // When
        let outputs = try await run(spec)

        // Then
        #expect(spec.procedures[entryName]?.signature.parameters["ratio"]?.default == .int(3))
        #expect(outputs["result"] == .double(3))
    }

    @Test("no inputs declaration is still a closed contract — strays are rejected")
    func strayInputRejectedOnEmptySignature() async throws {
        // Given — absent `inputs:` is an empty signature, not an absent contract
        let spec = try Loader.testing.loadProcedure(["body": [["id": "noop", "value": "ok"]]])

        // When / Then
        await #expect(throws: ArgumentError.self) {
            try await run(spec, arguments: ["stray": .string("leaked")])
        }
    }

    @Test("a null default is a declared default, not an absent one")
    func nullDefaultIsDeclared() throws {
        // Given — declaring `null` is what makes an input optional while still
        // saying what it is
        let sut = try Loader.testing.loadProcedure([
            "parameters": ["dir": ["type": "string", "default": .null]],
            "body": [["id": "seen", "value": ["ref": "dir"]]]
        ])

        // Then
        let parameter = try #require(sut.procedures[entryName]?.signature.parameters["dir"])

        #expect(parameter.default == .null)
        #expect(!parameter.isRequired)
    }

    @Test("probe: a null default inside a whole module document")
    func probeNullDefaultInModule() throws {
        // Given
        let sut = try Loader.testing.load([
            "name": "nullcwd",
            "procedures": [
                "nullcwd": [
                    "parameters": ["dir": ["type": "string", "default": .null]],
                    "body": [["id": "seen", "value": ["ref": "dir"]]]
                ]
            ]
        ])

        // Then
        #expect(sut.procedures["nullcwd"]?.signature.parameters["dir"]?.default == .null)
    }
}
