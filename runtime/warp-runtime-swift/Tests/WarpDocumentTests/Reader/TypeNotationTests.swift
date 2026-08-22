//
//  TypeNotationTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

@Suite("How a document spells a type")
struct TypeNotationTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("a built-in reads as its own name, applied or not")
    func builtinsParse() throws {
        #expect(try TypeReader.parse("string") == .string)
        #expect(try TypeReader.parse("array") == .array(.any))
        #expect(try TypeReader.parse("array<string>") == .array(.string))
        #expect(try TypeReader.parse("object<array<int>>") == .object(.array(.int)))
        #expect(try TypeReader.parse("procedure") == .procedure(nil))
        #expect(try TypeReader.parse("never") == .never)
    }

    @Test("a slot asks for purity by writing it in front")
    func purityIsWrittenAndRead() throws {
        // Given / When / Then
        #expect(try TypeReader.parse("pure procedure") == .procedure(nil, .pure))
        #expect(try TypeReader.parse("procedure") == .procedure(nil, .unstated))

        // Only a procedure answers without running, so only a procedure is
        // written pure.
        #expect(throws: TypeFormError.self) { try TypeReader.parse("pure string") }
    }

    @Test("a hole is written some, and is not a declared name")
    func holesAreWrittenAndRead() throws {
        // Given / When / Then
        #expect(try TypeReader.parse("some Element") == .variable("Element"))
        #expect(try TypeReader.parse("array<some Element>") == .array(.variable("Element")))

        // A bare name is looked up in the table of declared types; only `some`
        // says the call decides.
        #expect(try TypeReader.parse("Element") == .named("Element"))

        #expect(throws: TypeFormError.self) { try TypeReader.parse("some ") }
    }

    @Test("a name nothing builds in is a declared type")
    func unknownNameIsNamed() throws {
        #expect(try TypeReader.parse("Task") == .named("Task"))
    }

    @Test("an unbalanced argument is an author mistake, caught while reading")
    func unbalancedArgumentRejected() {
        #expect(throws: TypeFormError.self) { try TypeReader.parse("array<string") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("string>") }
        #expect(throws: TypeFormError.self) { try TypeReader.parse("string<int>") }
    }

    @Test("a module declares shapes its procedures name")
    func moduleDeclaresTypes() throws {
        // Given
        let sut = try loader.load([
            "types": ["Task": ["id": "string", "done": "bool"]],
            "procedures": [
                "entry": [
                    "parameters": ["tasks": "array<Task>"],
                    "body": [["id": "seen", "value": ["ref": "tasks"]]]
                ]
            ]
        ])

        // Then
        #expect(sut.types["Task"] == .record(["id": .string, "done": .bool]))
        #expect(
            sut.procedures["entry"]?.signature.parameters["tasks"]?.type
                == .array(.named("Task"))
        )
    }

    @Test("a declared shape is enforced at the call boundary")
    func declaredShapeIsEnforced() async throws {
        // Given
        let sut = try loader.load([
            "types": ["Task": ["id": "string"]],
            "procedures": [
                "entry": [
                    "parameters": ["tasks": "array<Task>"],
                    "body": [["id": "seen", "value": ["ref": "tasks"]]],
                    "result": ["result": ["ref": "seen"]]
                ]
            ]
        ])

        // When / Then
        let good = try await run(sut, arguments: ["tasks": .array([.object(["id": .string("a")])])])

        #expect(good["result"] == .array([.object(["id": .string("a")])]))

        await #expect(throws: ArgumentError.self) {
            try await run(sut, arguments: ["tasks": .array([.object(["id": .int(1)])])])
        }
    }
}
