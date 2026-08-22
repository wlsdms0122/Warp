//
//  ExpressionFormTests.swift
//  WarpDocumentTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import Warp
@testable import WarpDocument

@Suite
struct ExpressionFormTests {
    // MARK: - Property
    private let loader = Loader.testing

    // MARK: - Initializer
    // MARK: - Test
    @Test("a string spelling a placeholder stays a literal")
    func placeholderStringStaysLiteral() throws {
        // Given — the injection doctrine: no string is ever re-parsed into a ref
        let reference = try loader.expression(from: "${secret}")

        // Then
        guard case let .literal(.string(string)) = reference else {
            Issue.record("expected stringValue, got \(reference)")

            return
        }

        #expect(string == "${secret}")
        #expect(validates(reference))
    }

    @Test("a bytes value decodes as a bytes literal, and numbers stay numbers")
    func bytesDecodeAsBytes() throws {
        // Given — the one binary kind crosses the Value bridge whole; an array
        // of small numbers next to it must stay an array of numbers
        let bytes = try loader.expression(from: .bytes([0x6A, 0x73]))
        let numbers = try loader.expression(from: .array([.int(1), .int(2)]))

        // Then
        guard case let .literal(carried) = bytes else {
            Issue.record("expected a bytes literal, got \(bytes)")

            return
        }

        #expect(carried == .bytes([0x6A, 0x73]))

        guard case .array = numbers else {
            Issue.record("expected an array of numbers, got \(numbers)")

            return
        }
    }

    @Test("only the exact { ref: } form decodes as a reference")
    func exactRefFormDecodes() throws {
        // Given
        let reference = try loader.expression(from: ["ref": "items[0].name"])

        // Then
        #expect(reference.referencePath == [.key("items"), .index(0), .key("name")])
    }

    @Test("form-shaped data inside { value: } quotation stays inert")
    func quotedFormShapedPayloadStaysInert() throws {
        // Given — { value: } is quotation; ref-shaped data inside is data
        let reference = try loader.expression(from: ["value": ["ref": "secret"]])

        // Then
        guard case let .literal(payload) = reference else {
            Issue.record("expected quoted, got \(reference)")

            return
        }

        #expect(payload == .object(["ref": .string("secret")]))
        #expect(validates(reference), "quoted payloads are not even validation targets")
    }

    @Test("a half-spelled form record is rejected at load", arguments: [
        ["ref": "a", "extra": "b"] as Value,
        ["ref": 3],
        ["value": "a", "extra": "b"],
        ["with": ["a": 1]],
        ["format": "x", "extra": "b"],
        ["format": "x", "with": [1, 2]],
        ["format": ["a"], "with": ["a": 1]]
    ])
    func ambiguousFormRecordRejected(fixture: Value) {
        // When / Then — a half-spelled form is an author mistake, not a record;
        // plain data carrying these keys must be quoted with { value: }
        #expect(throws: DecodingError.self) {
            _ = try loader.expression(from: fixture)
        }
    }

    @Test("a placeholder undeclared in `with` is rejected")
    func undeclaredPlaceholderRejected() {
        // Given — the format surface is closed over its `with` bindings
        let fixture: Value = [
            "format": "hello, ${who} from ${where}",
            "with": ["who": ["ref": "who"]]
        ]

        // When / Then
        #expect(throws: DecodingError.self) {
            _ = try loader.expression(from: fixture)
        }
    }

    @Test("a closed format template decodes")
    func closedFormatDecodes() throws {
        // Given
        let reference = try loader.expression(from: [
            "format": "hello, ${who}",
            "with": ["who": ["ref": "who"]]
        ])

        // Then — outward references are the binding expressions, never the template
        #expect(validates(reference, visible: ["who"]))
        #expect(!validates(reference), "the binding expression reaches outward")
    }

    @Test("a template lowers to the words that build it")
    func templateLowersToWords() throws {
        // Given
        let reference = try loader.expression(from: [
            "format": "hello, ${who}",
            "with": ["who": ["ref": "name"]]
        ])

        // Then — nothing in the language knows what a template is: what is left
        // is an array written one after another, each value asked how it reads
        guard
            case let .dispatch(joined) = reference,
            case let .array(pieces) = joined.receiver
        else {
            Issue.record("expected a joined array, got \(reference)")

            return
        }

        #expect(joined.selector == Spelling.joined)
        #expect(pieces.count == 2)
        #expect(pieces.first?.constantValue == .string("hello, "))

        guard case let .dispatch(spelled)? = pieces.last else {
            Issue.record("expected the placeholder to ask how its value reads")

            return
        }

        // The binding is substituted, so the placeholder never names anything
        // the template was not given.
        #expect(spelled.selector == Spelling.read)
        #expect(spelled.receiver?.referencePath == [.key("name")])
    }

    @Test("an index reference inside a placeholder stays inside the template")
    func indexReferenceStaysClosed() throws {
        // Given — `${xs[i]}` names two bindings, and `validateClosed` makes the
        // author declare both. What is built must read both from the template
        let reference = try loader.expression(from: [
            "format": "at ${xs[i]}",
            "with": ["xs": ["ref": "items"], "i": ["ref": "cursor"]]
        ])

        // Then — the index must have been substituted too, or it resolves
        // against whatever scope the statement runs in
        guard
            case let .dispatch(joined) = reference,
            case let .array(pieces) = joined.receiver,
            case let .dispatch(spelled)? = pieces.last,
            case let .reference(path)? = spelled.receiver
        else {
            Issue.record("expected a spelled reference, got \(reference)")

            return
        }

        #expect(path == [.key("items"), .indexRef([.key("cursor")])])
    }

    @Test("a placeholder drilling into a computed binding is refused")
    func drillingIntoAComputedBindingIsRefused() {
        // Given / When / Then — continuing a path needs a path to continue, and
        // reading the placeholder as written would reach the ambient scope
        #expect(throws: (any Error).self) {
            try loader.expression(from: [
                "format": "hello, ${who.name}",
                "with": ["who": ["value": ["name": "warp"]]]
            ])
        }
    }

    @Test("an ordinary record without form keys passes unquoted")
    func plainRecordPassesWithoutFormKeys() throws {
        // Given — an ordinary record of expressions needs no quoting
        let reference = try loader.expression(from: ["name": "report", "target": ["ref": "target"]])

        // Then
        guard case let .record(record) = reference else {
            Issue.record("expected recordValue, got \(reference)")

            return
        }

        #expect(record["target"]?.referencePath == [.key("target")])
    }

}
