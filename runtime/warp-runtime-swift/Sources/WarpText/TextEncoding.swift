//
//  TextEncoding.swift
//  WarpText
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Warp

// The encoding a document is read in — by a person. The binary is what a
// document travels as; this is the same document laid out for eyes. A dump,
// not a syntax: machines write it, people read it, and composing by hand is a
// front end's job in a front end's notation — which is why there are no
// comments to lose on the way back.
//
// A whole number and a fraction are different tokens here by grammar — `1` is
// whole and `1.0` is a fraction. And there is nothing else: no commas to
// forget, no colons; a record is `{ key value … }` and an array is
// `[ value … ]`.
//
// One document, one text. The writer is canonical — sorted keys, one layout,
// one spelling per value — and the reader accepts exactly the canonical
// writing: a text that is not what the writer would write for the value it
// spells is not a document, byte for byte the same promise the binary keeps.
public enum TextEncoding {
    // MARK: - Property
    // The first tokens of every document: which encoding, laid out how. The
    // version moves when this file's grammar does, and for no other reason —
    // what the *program* needs of its reader is said inside the document.
    public static let name = "warpt"
    public static let format = 1

    // The same bound the binary reader holds, for the same reason: the depth of
    // a document must never be the depth of the host's call stack.
    static let depth = 512

    // MARK: - Public
    public static func text(from value: Value) throws -> String {
        var written = "\(name) \(format)\n"

        try write(value, at: 0, into: &written, within: depth)

        written += "\n"

        return written
    }

    public static func data(from value: Value) throws -> Data {
        Data(try text(from: value).utf8)
    }

    public static func value(from data: Data) throws -> Value {
        guard let text = String(bytes: data, encoding: .utf8) else {
            throw refused("the text is not UTF-8")
        }

        return try value(from: text)
    }

    public static func value(from text: String) throws -> Value {
        var tokens = try tokenized(text)[...]

        guard case .bare(name) = tokens.popFirst() else {
            throw refused("the text does not begin as a warp document begins")
        }

        guard case let .bare(version) = tokens.popFirst(), let claimed = Int(version) else {
            throw refused("the text does not say how it is laid out")
        }

        guard claimed == format else {
            throw refused(
                claimed > format
                    ? "the document is laid out as format \(claimed), and this reader lays out \(format)"
                    : "format \(claimed) never existed"
            )
        }

        let value = try read(from: &tokens)

        guard tokens.isEmpty else {
            throw refused("the document ended and the text did not")
        }

        // The half of canonical the grammar cannot see: spelling. Writing the
        // value back out and comparing bytes is the whole check — a fraction
        // written long, an escape written the four-digit way, an indent of
        // three spaces are each a second text for one document, and one
        // document has one text. Bytes, because Swift's own `==` compares
        // text under canonical equivalence and this rule is about spelling.
        guard let written = try? Self.text(from: value), written.utf8.elementsEqual(text.utf8) else {
            throw refused("the text is not the document's one writing")
        }

        return value
    }

    // MARK: - Private
    private enum Token: Equatable {
        case arrayOpen
        case arrayClose
        case recordOpen
        case recordClose
        case string(String)
        case bytes([UInt8])
        case bare(String)
    }

    // A container being put back together, exactly as in the binary reader —
    // one shape of reader per encoding would be two chances to differ. A sum
    // rather than two optionals, so "neither" and "both" are not states the
    // code has to promise never to reach; a record with no key is one waiting
    // for its next field name.
    private enum Opened {
        case array([Value])
        case record(held: [String: Value], key: String?, previous: [UInt8]?)
    }

    private static func tokenized(_ text: String) throws -> [Token] {
        var tokens: [Token] = []
        var reading = Array(text.unicodeScalars)[...]

        while let character = reading.first {
            switch character {
            case " ", "\n", "\r", "\t":
                reading.removeFirst()

            case "[":
                reading.removeFirst()
                tokens.append(.arrayOpen)

            case "]":
                reading.removeFirst()
                tokens.append(.arrayClose)

            case "{":
                reading.removeFirst()
                tokens.append(.recordOpen)

            case "}":
                reading.removeFirst()
                tokens.append(.recordClose)

            case "\"":
                reading.removeFirst()
                tokens.append(.string(try quoted(from: &reading)))

            default:
                var bare = ""

                while let character = reading.first,
                      !" \n\r\t[]{}\"".unicodeScalars.contains(character) {
                    bare.unicodeScalars.append(character)
                    reading.removeFirst()
                }

                // `x` straight into a quote is the bytes spelling — one token,
                // because the quote is a delimiter and not text
                if bare == "x", reading.first == "\"" {
                    reading.removeFirst()
                    tokens.append(.bytes(try hexed(from: &reading)))
                } else {
                    tokens.append(.bare(bare))
                }
            }
        }

        return tokens
    }

    private static func quoted(from reading: inout ArraySlice<Unicode.Scalar>) throws -> String {
        var string = ""

        while let character = reading.first {
            reading.removeFirst()

            switch character {
            case "\"":
                return string

            case "\\":
                string.unicodeScalars.append(try escaped(from: &reading))

            default:
                guard character.value >= 0x20 else {
                    throw refused("text holds a control character written raw")
                }

                string.unicodeScalars.append(character)
            }
        }

        throw refused("the text ends inside text")
    }

    private static func escaped(from reading: inout ArraySlice<Unicode.Scalar>) throws -> Unicode.Scalar {
        guard let character = reading.first else {
            throw refused("the text ends inside an escape")
        }

        reading.removeFirst()

        switch character {
        case "\"": return "\""
        case "\\": return "\\"
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"

        case "u":
            let first = try hexadecimal(from: &reading)

            // A surrogate pair is two escapes carrying one character
            guard 0xd800...0xdbff ~= first else {
                guard let scalar = Unicode.Scalar(first) else {
                    throw refused("the escape names no character")
                }

                return scalar
            }

            guard reading.first == "\\" else { throw refused("the escape names half a character") }

            reading.removeFirst()

            guard reading.first == "u" else { throw refused("the escape names half a character") }

            reading.removeFirst()

            let second = try hexadecimal(from: &reading)

            guard 0xdc00...0xdfff ~= second,
                  let scalar = Unicode.Scalar(
                    0x10000 + ((first - 0xd800) << 10) + (second - 0xdc00)
                  ) else {
                throw refused("the escape names no character")
            }

            return scalar

        default:
            throw refused("nothing is written \\\(character)")
        }
    }

    // The body of `x"…"`: lowercase hex, two digits a byte, nothing else —
    // uppercase or odd length would be a second spelling for the same bytes.
    private static func hexed(from reading: inout ArraySlice<Unicode.Scalar>) throws -> [UInt8] {
        var digits: [UInt8] = []

        while let character = reading.first, character != "\"" {
            reading.removeFirst()

            switch character {
            case "0"..."9":
                digits.append(UInt8(character.value - 0x30))

            case "a"..."f":
                digits.append(UInt8(character.value - 0x61 + 10))

            default:
                throw refused("bytes are written as lowercase hex")
            }
        }

        guard reading.first == "\"" else {
            throw refused("the text ends inside bytes")
        }

        reading.removeFirst()

        guard digits.count % 2 == 0 else {
            throw refused("bytes are written two digits each")
        }

        return stride(from: 0, to: digits.count, by: 2)
            .map { index in digits[index] << 4 | digits[index + 1] }
    }

    private static func hexadecimal(from reading: inout ArraySlice<Unicode.Scalar>) throws -> UInt32 {
        var value: UInt32 = 0

        for _ in 0..<4 {
            guard let character = reading.first,
                  character.isASCII,
                  let digit = UInt32(String(character), radix: 16) else {
                throw refused("the escape is not four hexadecimal digits")
            }

            value = value << 4 | digit

            reading.removeFirst()
        }

        return value
    }

    private static func read(from tokens: inout ArraySlice<Token>) throws -> Value {
        var opened: [Opened] = []

        while true {
            guard opened.count <= depth else {
                throw refused("the document nests deeper than a reader must follow")
            }

            guard let token = tokens.popFirst() else {
                throw refused("the text ends where a value should begin")
            }

            var settled: Value?

            // A record waits for a key where everything else waits for a value,
            // and a closing brace is only honest in that position
            if case .record(let held, .none, let previous) = opened.last {
                switch token {
                case .recordClose:
                    opened.removeLast()

                    settled = .object(held)

                case let .bare(name) where identifier(name):
                    opened[opened.count - 1] = .record(
                        held: held,
                        key: name,
                        previous: try expect(name, after: previous)
                    )

                    continue

                case let .string(name):
                    opened[opened.count - 1] = .record(
                        held: held,
                        key: name,
                        previous: try expect(name, after: previous)
                    )

                    continue

                default:
                    throw refused("a record writes a field name here")
                }
            } else {
                switch token {
                case .arrayOpen:
                    opened.append(.array([]))

                    continue

                case .recordOpen:
                    opened.append(.record(held: [:], key: nil, previous: nil))

                    continue

                case .arrayClose:
                    guard case let .array(held) = opened.last else {
                        throw refused("nothing here is an array to close")
                    }

                    opened.removeLast()

                    settled = .array(held)

                case .recordClose:
                    throw refused("nothing here is a record to close")

                case let .string(string):
                    settled = .string(string)

                case let .bytes(bytes):
                    settled = .bytes(bytes)

                case let .bare(bare):
                    settled = try scalar(from: bare)
                }
            }

            // Closing is a token here, not a count, so a settled value climbs
            // one step at most: into whatever holds it, or out
            if let value = settled {
                guard let open = opened.popLast() else { return value }

                switch open {
                case .array(var held):
                    held.append(value)

                    opened.append(.array(held))

                case .record(var held, let key?, let previous):
                    // Unique because the keys arrived strictly ascending and
                    // in NFC: byte order refuses a byte-equal duplicate, and
                    // NFC leaves one name one byte spelling to be equal in.
                    held[key] = value

                    opened.append(.record(held: held, key: nil, previous: previous))

                // A record with no key is waiting for a field name, and every
                // token it could meet in that state was answered above
                case .record(_, .none, _):
                    throw refused("a record writes a field name here")
                }
            }
        }
    }

    // What a bare token names. Everything unquoted is one of five things, and a
    // number is whole or a fraction by grammar — a point or an exponent, not a
    // reader's guess.
    private static func scalar(from bare: String) throws -> Value {
        switch bare {
        case "null": return .null
        case "true": return .bool(true)
        case "false": return .bool(false)

        default:
            guard let first = bare.first, first == "-" || first.isNumber else {
                throw refused("nothing is written \(bare)")
            }

            guard bare.contains(where: { character in ".eE".contains(character) }) else {
                guard let int = Int(bare) else {
                    throw refused("\(bare) is not a number a document holds")
                }

                return .int(int)
            }

            guard let double = Double(bare), double.isFinite else {
                throw refused("\(bare) is not a number a document holds")
            }

            return .double(double)
        }
    }

    private static func expect(_ key: String, after previous: [UInt8]?) throws -> [UInt8] {
        let raw = Array(key.utf8)

        if let previous, !previous.lexicographicallyPrecedes(raw) {
            throw refused("the record's keys are not written in order")
        }

        guard normal(key) else {
            throw refused("the field name is not in normal form C")
        }

        return raw
    }

    // Whether a name is its own NFC form, by bytes — Swift's own `==` compares
    // under canonical equivalence, which is exactly the difference this rule
    // exists to see. ASCII always passes.
    private static func normal(_ name: String) -> Bool {
        Name.isNormal(name)
    }

    // ASCII on purpose, not for lack of ambition: "is this a letter" for the
    // rest of Unicode is answered by whatever tables a host language shipped,
    // and a canonical layout cannot depend on whose tables were newer. A name
    // outside this set is simply quoted, which every implementation spells the
    // same way.
    private static func identifier(_ name: String) -> Bool {
        func word(_ character: Character, first: Bool) -> Bool {
            character.isASCII
                && (character.isLetter || character == "_" || (!first && character.isNumber))
        }

        guard let first = name.first, word(first, first: true) else { return false }

        return name.allSatisfy { character in word(character, first: false) }
    }

    private static func write(
        _ value: Value,
        at indent: Int,
        into text: inout String,
        within depth: Int
    ) throws {
        guard depth >= 0 else {
            throw EncodingError.invalidValue(
                value,
                .init(
                    codingPath: [],
                    debugDescription: "the value nests deeper than a document may"
                )
            )
        }

        switch value {
        case .null:
            text += "null"

        case let .bool(bool):
            text += bool ? "true" : "false"

        case let .int(int):
            text += "\(int)"

        case let .double(double):
            guard double.isFinite else {
                throw EncodingError.invalidValue(
                    value,
                    .init(
                        codingPath: [],
                        debugDescription: "a document has no way to carry \(double)"
                    )
                )
            }

            text += written(double)

        case let .string(string):
            write(string, into: &text)

        case let .bytes(bytes):
            text += "x\""
            text += bytes.map { byte in String(format: "%02x", byte) }.joined()
            text += "\""

        case let .array(array):
            guard !array.isEmpty else {
                text += "[]"

                break
            }

            text += "[\n"

            for element in array {
                text += String(repeating: "  ", count: indent + 1)

                try write(element, at: indent + 1, into: &text, within: depth - 1)

                text += "\n"
            }

            text += String(repeating: "  ", count: indent) + "]"

        case let .object(object):
            guard !object.isEmpty else {
                text += "{}"

                break
            }

            text += "{\n"

            let fields = object.map { field in (Array(field.key.utf8), field.key, field.value) }
                .sorted { one, other in one.0.lexicographicallyPrecedes(other.0) }

            for (_, key, value) in fields {
                // The same rule the reader holds: one name, one byte spelling
                guard normal(key) else {
                    throw EncodingError.invalidValue(
                        Value.string(key),
                        .init(
                            codingPath: [],
                            debugDescription: "the field name is not in normal form C"
                        )
                    )
                }

                text += String(repeating: "  ", count: indent + 1)

                if identifier(key) {
                    text += key
                } else {
                    write(key, into: &text)
                }

                text += " "

                try write(value, at: indent + 1, into: &text, within: depth - 1)

                text += "\n"
            }

            text += String(repeating: "  ", count: indent) + "}"

        case .procedure:
            throw EncodingError.invalidValue(
                value,
                .init(
                    codingPath: [],
                    debugDescription: "a procedure is code, and data is what a document spells"
                )
            )
        }
    }

    // A fraction, written so it reads back as one — the document's rule, not
    // an encoding's: a number with neither point nor exponent is whole
    private static func written(_ double: Double) -> String {
        let plain = "\(double)"

        return plain.contains(".") || plain.contains("e") ? plain : plain + ".0"
    }

    private static func write(_ string: String, into text: inout String) {
        text += "\""

        for character in string.unicodeScalars {
            switch character {
            case "\"": text += "\\\""
            case "\\": text += "\\\\"
            case "\n": text += "\\n"
            case "\r": text += "\\r"
            case "\t": text += "\\t"

            default:
                guard character.value < 0x20 else {
                    text.unicodeScalars.append(character)

                    continue
                }

                text += String(format: "\\u%04x", character.value)
            }
        }

        text += "\""
    }

    private static func refused(_ said: String) -> Error {
        DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: said))
    }
}
