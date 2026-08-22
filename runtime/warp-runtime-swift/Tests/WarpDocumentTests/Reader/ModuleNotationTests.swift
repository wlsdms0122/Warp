//
//  ModuleNotationTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

// The envelope a document is written in. Other suites here write one procedure
// and let `loadProcedure` name it; this one writes the envelope out.
@Suite
struct ModuleNotationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a document declares procedures and nothing that runs")
    func documentDeclaresProcedures() throws {
        // Given / When
        let sut = try loader.load([
            "name": "deploy",
            "description": "a document is a module",
            "procedures": [
                "verify": [
                    "parameters": ["path": "string"],
                    "body": [["id": "done", "value": ["ref": "path"]]]
                ],
                "report": ["body": [["id": "done", "value": "reported"]]]
            ]
        ])

        // Then
        #expect(sut.name == "deploy")
        #expect(Set(sut.procedures.keys) == ["verify", "report"])
    }

    @Test("a top-level body is rejected, because a document is not a procedure")
    func topLevelBodyRejected() {
        // Given — this was the whole shape of a document once, and it made
        // every document an entry point with no way to write one that only
        // declares
        let fixture: Value = ["name": "legacy", "body": [["id": "done", "value": "end"]]]

        // When / Then
        #expect(throws: DecodingError.self) {
            try loader.load(fixture)
        }
    }

    @Test("a module that declares nothing is rejected")
    func emptyModuleRejected() {
        // Given — it could never be linked into anything
        let fixture: Value = ["name": "empty", "procedures": [:]]

        // When / Then
        #expect(throws: DecodingError.self) {
            try loader.load(fixture)
        }
    }

    @Test("a procedure carries no name of its own")
    func procedureIsNamedByItsKey() {
        // Given — the key is the name, so writing it twice invites the two to
        // disagree
        let fixture: Value = [
            "procedures": [
                "verify": ["name": "something-else", "body": [["id": "done", "value": "end"]]]
            ]
        ]

        // When / Then
        #expect(throws: DecodingError.self) {
            try loader.load(fixture)
        }
    }

    @Test("a procedure may describe itself")
    func procedureKeepsItsDescription() throws {
        // Given / When
        let sut = try loader.load([
            "procedures": [
                "verify": [
                    "description": "checks the thing",
                    "body": [["id": "done", "value": "end"]]
                ]
            ]
        ])

        // Then
        #expect(sut.procedures["verify"]?.description == "checks the thing")
    }

    @Test("every procedure in a module is validated, not only the one that runs")
    func everyProcedureIsValidated() {
        // Given — a document is checked against itself, and which one will be
        // the entry is not known here
        let fixture: Value = [
            "procedures": [
                "fine": ["body": [["id": "done", "value": "end"]]],
                "broken": ["body": [["id": "done", "value": ["ref": "nowhere"]]]]
            ]
        ]

        // When / Then
        #expect(throws: ValidationError.self) {
            try loader.load(fixture)
        }
    }
}
