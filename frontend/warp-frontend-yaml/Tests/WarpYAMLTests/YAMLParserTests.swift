//
//  YAMLParserTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 8/18/26.
//

import Foundation
import Testing
import Warp
@testable import WarpYAML

// A front end is a function from text to `Value`, and this is that function's
// whole contract: the shapes it builds, and the ways it refuses.
@Suite("Text becoming a value")
struct YAMLParserTests {
    // MARK: - Property
    private let sut = YAMLParser()

    // MARK: - Lifecycle
    // MARK: - Test
    @Test("the three container shapes build the three value shapes")
    func containersBecomeValues() throws {
        // Given / When
        let parsed = try sut.parse("""
        name: greeter
        rounds:
          - 1
          - 2
        nested:
          inner: true
        """)

        // Then
        #expect(parsed == [
            "name": "greeter",
            "rounds": [1, 2],
            "nested": ["inner": true]
        ])
    }

    @Test("a quoted scalar is text, whatever it would have meant unquoted", arguments: [
        "\"true\"",
        "'3'",
        "\"null\"",
        "\"1.5\""
    ])
    func quotedScalarsStayText(written: String) throws {
        // Given — the retyping rule reads plain scalars only, so quoting is how a
        // document says "this is text" and it has to hold for every word that
        // would otherwise be taken
        let parsed = try sut.parse("subject: \(written)")

        // Then
        guard case let .object(object) = parsed else {
            Issue.record("expected an object, got \(parsed)")

            return
        }

        #expect(object["subject"]?.type == .string)
    }

    @Test("a block scalar is text")
    func blockScalarsStayText() throws {
        // Given / When
        let parsed = try sut.parse("""
        subject: |
          true
        """)

        // Then
        #expect(parsed["subject"]?.type == .string)
    }

    @Test("bytes are read as UTF-8")
    func dataIsReadAsText() throws {
        // Given / When
        let parsed = try sut.parse(Data("subject: 3".utf8))

        // Then
        #expect(parsed == ["subject": 3])
    }

    @Test("bytes that are not UTF-8 are refused")
    func invalidBytesAreRefused() {
        // Given — a lone continuation byte is not a UTF-8 sequence
        let bytes = Data([0xFF, 0xFE, 0xFD])

        // When / Then
        #expect(throws: DecodingError.self) {
            try sut.parse(bytes)
        }
    }

    @Test("text that is not YAML is refused, and says so")
    func malformedTextIsRefused() {
        // Given / When / Then
        #expect(throws: DecodingError.self) {
            try sut.parse("name: [unclosed")
        }
    }

    @Test("an empty document is refused rather than read as nothing")
    func emptyDocumentIsRefused() {
        // Given — nothing is not a value, and a loader handed one would be told a
        // module declares nothing rather than that the file was blank
        #expect(throws: DecodingError.self) {
            try sut.parse("")
        }
        #expect(throws: DecodingError.self) {
            try sut.parse("# only a comment\n")
        }
    }

    @Test("a key that is not a scalar is refused")
    func nonScalarKeyIsRefused() {
        // Given — `Value`'s records are keyed by strings, so a sequence key has
        // nothing to become
        #expect(throws: DecodingError.self) {
            try sut.parse("""
            ? [a, b]
            : taken
            """)
        }
    }

    @Test("a number the reader cannot hold is refused rather than approximated", arguments: [
        "999999999999999999999999999999",
        "1e999"
    ])
    func unholdableNumberIsRefused(written: String) {
        // Given — a whole number wider than an int must not fall through to the
        // float pattern and answer roughly itself, which is a document being read
        // as one it is not
        #expect(throws: DecodingError.self) {
            try sut.parse("subject: \(written)")
        }
    }
}
