//
//  ValueWriter.swift
//  WarpDocument
//
//  Created by JSilver on 8/19/26.
//

import Foundation
import Warp

// Data written the way a document spells it — `ValueReader` the other way round,
// and the reason both live here: `Value` is the language's data type and knows
// nothing about being written down, so the mapping belongs in one place and this
// is it.
//
// The pair round-trips, which is the whole of what it promises. A procedure has
// no spelling, so writing one refuses rather than putting something in the text
// that reading it back could not answer with.
public struct ValueWriter: Encodable {
    // MARK: - Property
    public let value: Value

    // MARK: - Initializer
    public init(_ value: Value) {
        self.value = value
    }

    // MARK: - Public
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case .null:
            try container.encodeNil()

        case let .bool(bool):
            try container.encode(bool)

        case let .int(int):
            try container.encode(int)

        case let .double(double):
            try container.encode(double)

        case let .string(string):
            try container.encode(string)

        // A Codable carrier has one kind of text and no kind of bytes, so any
        // spelling written here would read back as something else. The warp
        // encodings carry bytes natively; this projection refuses them.
        case .bytes:
            throw EncodingError.invalidValue(
                value,
                .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "this notation has no spelling for bytes"
                )
            )

        case let .array(array):
            try container.encode(array.map(ValueWriter.init))

        case let .object(object):
            try container.encode(object.mapValues(ValueWriter.init))

        // A body is code, and a document spells code as a procedure rather than
        // as data. Writing a marker would make a document that cannot be read
        // back into what it came from.
        case .procedure:
            throw EncodingError.invalidValue(
                value,
                .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "a procedure is code, and data is what a document spells"
                )
            )
        }
    }

    // MARK: - Private
}
