//
//  YAMLScalarTypingTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
import WarpYAML
@testable import Warp

// Scalar typing is the parser's answer alone — nothing about procedures is under
// test here, so nothing about procedures is loaded.
@Suite
struct YAMLScalarTypingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("plain scalars take JSON literal typing only", arguments: [
        ("value: no", Value.string("no")),
        ("value: on", Value.string("on")),
        ("value: \"09:20\"", Value.string("09:20")),
        ("value: 09:20", Value.string("09:20")),
        ("value: 007", Value.string("007")),
        ("value: true", Value.bool(true)),
        ("value: false", Value.bool(false)),
        ("value: 42", Value.int(42)),
        ("value: -7", Value.int(-7)),
        ("value: 1.5", Value.double(1.5)),
        ("value: \"42\"", Value.string("42")),
        ("value: null", Value.null),
        ("value: ~", Value.null)
    ])
    func plainScalarsTakeJSONLiteralTypingOnly(
        yaml: String,
        expected: Value
    ) throws {
        // Given / When
        let decoded = try object(yaml)

        // Then
        #expect(decoded["value"] == expected)
    }

    @Test("anchor aliases share the value")
    func aliasesShareValueThroughAnchor() throws {
        // Given
        let yaml = """
        base: &anchor 1
        copy: *anchor
        """

        // When
        let decoded = try object(yaml)

        // Then
        #expect(decoded["copy"] == .int(1))
    }

    @Test("numeric typing survives the YAML load", arguments: [
        ("value: 3.0", Value.double(3.0)),
        ("value: 3.5e1", Value.double(35.0)),
        ("value: 42", Value.int(42))
    ])
    func numericTypingSurvivesYAMLLoad(
        yaml: String,
        expected: Value
    ) throws {
        // Given / When — no JSON text round trip to collapse `3.0` into int
        let decoded = try object(yaml)

        // Then
        #expect(decoded["value"] == expected)
    }

    // MARK: - Private
    private func object(_ yaml: String) throws -> [String: Value] {
        guard case let .object(object) = try YAMLParser().parse(Data(yaml.utf8)) else {
            throw ExecutionError("the document is not a mapping")
        }

        return object
    }
}
