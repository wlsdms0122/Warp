//
//  Rendering.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// A value on its way into a template. JSON is the shape a list or a mapping
// shows as, and this is the one thing in the package that writes one.
//
// It is a wrapper rather than a conformance on `Value` because the two are not
// the same job. `Value` is the language's data type and knows nothing about
// being written down — what a document spells is `WarpDocument`'s, and it round-trips.
// This does not: a procedure has no data form, and what goes out for one is a
// marker saying so, which is right for something a person reads and wrong for
// anything that means to read it back.
struct Rendering: Encodable {
    // MARK: - Property
    let value: Value

    // The value as text. One implementation, because `text` the word and an
    // effect settling an argument are asking the same question.
    var text: String {
        switch value {
        case .null:
            return ""

        case let .bool(bool):
            return bool ? "true" : "false"

        case let .int(integer):
            return String(integer)

        case let .double(double):
            return String(double)

        case let .string(string):
            return string

        // Bytes are not text; what shows is a reading of them — hex digits —
        // and not an encoding's grammar, which is an encoding's to own.
        case let .bytes(bytes):
            return Self.spelled(bytes)

        // A body has no text an author wrote it to produce, so what shows is
        // what it is.
        case .procedure:
            return "<procedure>"

        case .array, .object:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

            guard
                let data = try? encoder.encode(self),
                let written = String(data: data, encoding: .utf8)
            else {
                return "<unencodable>"
            }

            return written
        }
    }

    // MARK: - Initializer
    init(_ value: Value) {
        self.value = value
    }

    // MARK: - Public
    func encode(to encoder: Encoder) throws {
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

        case let .bytes(bytes):
            try container.encode(Self.spelled(bytes))

        case let .array(array):
            try container.encode(array.map(Rendering.init))

        case let .object(object):
            try container.encode(object.mapValues(Rendering.init))

        // A template that mentions a procedure should read as one, rather than
        // fail for saying something true.
        case .procedure:
            try container.encode("<procedure>")
        }
    }

    // MARK: - Private
    private static func spelled(_ bytes: [UInt8]) -> String {
        bytes.map { byte in String(format: "%02x", byte) }.joined()
    }
}
