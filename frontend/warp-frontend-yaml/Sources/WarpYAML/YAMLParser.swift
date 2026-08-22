//
//  YAMLParser.swift
//  WarpYAML
//
//  Created by JSilver on 8/15/26.
//

import Foundation
import Yams
import Warp

// A front end is a function from text to `Value`. Nothing about the language
// lives here — this file knows YAML and knows nothing about procedures, steps or
// actions, and the core knows procedures and has never heard of YAML.
public struct YAMLParser: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func parse(_ data: Data) throws -> Value {
        guard let text = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "input is not valid UTF-8")
            )
        }

        return try parse(text)
    }

    public func parse(_ text: String) throws -> Value {
        let root: Node?

        do {
            root = try Yams.compose(yaml: text)
        } catch {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "The given data was not valid YAML.",
                    underlyingError: error
                )
            )
        }

        guard let root else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "empty YAML document")
            )
        }

        return try value(fromNode: root)
    }

    // MARK: - Private
    private func value(fromNode node: Node) throws -> Value {
        switch node {
        case let .scalar(scalar):
            return try value(fromScalar: scalar)

        case let .sequence(sequence):
            return .array(try sequence.map(value(fromNode:)))

        case let .mapping(mapping):
            var object: [String: Value] = [:]

            for (key, entry) in mapping {
                guard case let .scalar(scalarKey) = key else {
                    throw DecodingError.dataCorrupted(
                        .init(
                            codingPath: [],
                            debugDescription: "non-scalar mapping key is not supported"
                        )
                    )
                }

                object[scalarKey.string] = try value(fromNode: entry)
            }

            return .object(object)

        // compose resolves aliases into their anchored values before this walk —
        // aliases work. This branch is defensive against a future Yams surfacing
        // one unresolved.
        case .alias:
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "unresolved YAML alias — compose should have"
                        + " resolved it"
                )
            )
        }
    }

    private func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    // Only plain scalars are retyped, and only by JSON literal rules — `no`, `on`,
    // `09:20`, `007` stay strings instead of taking YAML 1.1 reinterpretation, and
    // quoted/block scalars are always strings.
    private func value(fromScalar scalar: Node.Scalar) throws -> Value {
        guard scalar.style == .plain || scalar.style == .any else {
            return .string(scalar.string)
        }

        let text = scalar.string

        switch text {
        case "", "~", "null":
            return .null

        case "true":
            return .bool(true)

        case "false":
            return .bool(false)

        default:
            if matches(text, #"^-?(0|[1-9][0-9]*)$"#) {
                // A whole number too wide for `Int` is refused rather than
                // widened. Falling through would have matched the float pattern
                // and answered a `Double`, so a document that wrote every digit
                // would have been read as one that wrote roughly that many.
                guard let integer = Int(text) else {
                    throw DecodingError.dataCorrupted(
                        .init(
                            codingPath: [],
                            debugDescription: "whole number '\(text)' does not fit an"
                                + " int — quote it if you meant a string"
                        )
                    )
                }

                return .int(integer)
            }

            if
                matches(text, #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"#),
                let double = Double(text)
            {
                guard double.isFinite else {
                    throw DecodingError.dataCorrupted(
                        .init(
                            codingPath: [],
                            debugDescription: "numeric literal '\(text)' overflows the JSON"
                                + " number range — quote it if you meant a string"
                        )
                    )
                }

                return .double(double)
            }

            return .string(text)
        }
    }
}
