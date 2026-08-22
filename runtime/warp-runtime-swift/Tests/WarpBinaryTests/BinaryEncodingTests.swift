//
//  BinaryEncodingTests.swift
//  WarpBinaryTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
import Warp
@testable import WarpBinary

// Warp's own bytes, held to the two promises that justify having our own:
// the same document is the same bytes, and bytes the writer would not write
// are refused rather than read charitably.
@Suite("The binary encoding")
struct BinaryEncodingTests {
    // MARK: - Property
    // MARK: - Test
    @Test("every kind of value survives the round trip")
    func everyKindComesBack() throws {
        // Given — one of everything a document can hold, nested enough to make
        // the walk mean something
        let document = Value.object([
            "null": .null,
            "flags": .array([.bool(true), .bool(false)]),
            "counts": .array([.int(0), .int(-1), .int(Int.max), .int(Int.min)]),
            "ratio": .double(3.5),
            "name": .string("héllo, 世界"),
            "empty": .object([:]),
            "nothing": .array([])
        ])

        // When
        let bytes = try BinaryEncoding.data(from: document)

        // Then
        #expect(try BinaryEncoding.value(from: bytes) == document)
    }

    @Test("the same document is the same bytes, whatever order it was built in")
    func equalDocumentsAreEqualBytes() throws {
        // Given — two tables that hold the same fields, written into the
        // dictionary in opposite orders
        var forward: [String: Value] = [:]
        var backward: [String: Value] = [:]

        for (index, key) in ["a", "b", "c", "d", "e"].enumerated() {
            forward[key] = .int(index)
        }

        for (index, key) in ["a", "b", "c", "d", "e"].enumerated().reversed() {
            backward[key] = .int(index)
        }

        // Then
        #expect(
            try BinaryEncoding.data(from: .object(forward))
                == BinaryEncoding.data(from: .object(backward))
        )
    }

    @Test("the bytes are the bytes the format says")
    func theGoldenBytes() throws {
        // Given — a document small enough to lay out by hand. If this test
        // moves, the format moved, and the format version had better move with
        // it — a round-trip test alone would happily follow the code anywhere.
        let document = Value.object([
            "a": .int(1),
            "b": .array([.bool(true), .null]),
            "c": .string("hi"),
            "d": .double(1.5),
            "e": .bytes([0x6a, 0x73])
        ])

        let golden: [UInt8] = [
            0x57, 0x41, 0x52, 0x50,   // WARP
            0x01,                     // format 1
            0x07, 0x05,               // a record of five
            0x01, 0x61, 0x03, 0x02,                     // "a": int 1 (zigzag 2)
            0x01, 0x62, 0x06, 0x02, 0x02, 0x00,         // "b": [true, null]
            0x01, 0x63, 0x05, 0x02, 0x68, 0x69,         // "c": "hi"
            0x01, 0x64, 0x04,                           // "d": the fraction 1.5
            0x3f, 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x01, 0x65, 0x08, 0x02, 0x6a, 0x73          // "e": two bytes
        ]

        // Then
        #expect(try BinaryEncoding.data(from: document) == Data(golden))
        #expect(try BinaryEncoding.value(from: Data(golden)) == document)
    }

    @Test("a whole number and a fraction are different bytes")
    func wholeAndFractionDiffer() throws {
        // Given — the failure JSON invites: `1` and `1.0` as the same token
        let whole = try BinaryEncoding.data(from: .int(1))
        let fraction = try BinaryEncoding.data(from: .double(1))

        // Then
        #expect(whole != fraction)
        #expect(try BinaryEncoding.value(from: whole) == .int(1))
        #expect(try BinaryEncoding.value(from: fraction) == .double(1))
    }

    @Test("bytes that do not begin as a document are refused")
    func aForeignHeaderIsRefused() throws {
        // Given — JSON bytes, which is what will actually be handed to this
        // reader by mistake
        for bytes in [Data("{}".utf8), Data(), Data([0x57, 0x41])] {
            #expect {
                try BinaryEncoding.value(from: bytes)
            } throws: { error in
                "\(error)".contains("begin") || "\(error)".contains("end")
            }
        }
    }

    @Test("a document laid out by a later format is refused, not guessed at")
    func aLaterFormatIsRefused() {
        // Given — the header's version exists for exactly this reader
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x02, 0x00])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("later") || "\(error)".contains("format 2")
        }

        // And a format that never existed is not an earlier one
        #expect(throws: (any Error).self) {
            try BinaryEncoding.value(from: Data([0x57, 0x41, 0x52, 0x50, 0x00, 0x00]))
        }
    }

    @Test("bytes after the document are refused")
    func trailingBytesAreRefused() {
        // Given — a null, and then a byte nobody asked for. Reading what fits
        // and ignoring the rest is how two readers run two different programs.
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x00, 0x00])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("the bytes did not")
        }
    }

    @Test("a tag the format never assigned is refused")
    func anUnknownTagIsRefused() {
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x09])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("begins with")
        }
    }

    @Test("a length that claims more than the document holds is refused")
    func aLyingLengthIsRefused() {
        // Given — text claiming four gigabytes, in a document of six bytes.
        // The refusal has to come before anything is set aside for the claim.
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x05, 0xff, 0xff, 0xff, 0xff, 0x0f])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("claims more")
        }
    }

    @Test("nested claims cannot sum past the document")
    func nestedClaimsShareOneBudget() {
        // Given — fifty records, each opened with four bytes and each claiming
        // a hundred fields. Each claim alone fits the bytes that remain, which
        // is how a check local to one claim approved all fifty and set aside
        // memory for five thousand fields of a two-hundred-byte document.
        var bytes: [UInt8] = [0x57, 0x41, 0x52, 0x50, 0x01]

        for _ in 0..<50 {
            bytes += [0x07, 0x64, 0x01, 0x61]   // a record of "a hundred", field "a"
        }

        bytes.append(0x00)

        #expect {
            try BinaryEncoding.value(from: Data(bytes))
        } throws: { error in
            "\(error)".contains("claims more")
        }
    }

    @Test("a record with its keys out of order is refused")
    func aShuffledRecordIsRefused() {
        // Given — "b" before "a": bytes the writer would never produce, so
        // reading them would mean two spellings of one document
        let bytes = Data([
            0x57, 0x41, 0x52, 0x50, 0x01,
            0x07, 0x02,
            0x01, 0x62, 0x00,   // "b": null
            0x01, 0x61, 0x00    // "a": null
        ])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("order")
        }
    }

    @Test("a record that names a field twice is refused")
    func aDuplicateKeyIsRefused() {
        // Given — the same field twice with different values. Last-one-wins is
        // an answer, but it is the reader deciding what the writer meant.
        let bytes = Data([
            0x57, 0x41, 0x52, 0x50, 0x01,
            0x07, 0x02,
            0x01, 0x61, 0x03, 0x02,   // "a": 1
            0x01, 0x61, 0x03, 0x04    // "a": 2
        ])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("order")
        }
    }

    @Test("a field name outside normal form C is refused")
    func aDenormalKeyIsRefused() throws {
        // Given — é as e-plus-mark: valid UTF-8, ascending order, and a second
        // byte spelling for a name whose NFC form is one character. Accepting
        // it would let one name sort to two places and a record hold a field
        // twice, losing one without a word.
        let bytes = Data([
            0x57, 0x41, 0x52, 0x50, 0x01,
            0x07, 0x01,
            0x03, 0x65, 0xcc, 0x81, 0x00    // "é" (NFD): null
        ])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("normal form")
        }

        // And the same name in NFC is a document
        let normal = Data([
            0x57, 0x41, 0x52, 0x50, 0x01,
            0x07, 0x01,
            0x02, 0xc3, 0xa9, 0x00          // "é" (NFC): null
        ])

        #expect(try BinaryEncoding.value(from: normal) == .object(["é": .null]))
    }

    @Test("bytes that end inside bytes are refused")
    func truncatedBytesAreRefused() {
        // Given — bytes claiming three and carrying one
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x08, 0x03, 0x6a])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("end inside")
        }
    }

    @Test("a field name outside normal form C is refused on the way out too")
    func aDenormalKeyIsRefusedWhenWriting() {
        #expect {
            try BinaryEncoding.data(from: .object(["e\u{301}": .int(1)]))
        } throws: { error in
            "\(error)".contains("normal form")
        }
    }

    @Test("a number written longer than it is is refused")
    func aPaddedNumberIsRefused() {
        // Given — zero written in two bytes. One value, one spelling; the
        // second spelling is where byte equality and document equality part.
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x03, 0x80, 0x00])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("longer than it is")
        }
    }

    @Test("a number that does not fit in 64 bits is refused")
    func anOverflowingNumberIsRefused() {
        // Given — eleven continuation bytes of all-ones
        let bytes = Data(
            [0x57, 0x41, 0x52, 0x50, 0x01, 0x03] + Array(repeating: UInt8(0xff), count: 11)
        )

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("64 bits")
        }
    }

    @Test("bytes that end in the middle of a value are refused")
    func truncationIsRefused() throws {
        // Given — a healthy document cut at every possible place. Whatever byte
        // it loses, the answer is a refusal and never a smaller document.
        let bytes = try BinaryEncoding.data(
            from: .object(["a": .array([.int(300), .string("hi"), .double(1.5)])])
        )

        for end in 5..<bytes.count {
            #expect(throws: (any Error).self) {
                try BinaryEncoding.value(from: bytes.prefix(end))
            }
        }
    }

    @Test("a document nested past following is an attack, not a program")
    func bottomlessNestingIsRefused() {
        // Given — six hundred arrays each holding the next. No writer recursing
        // over a real value produces this; a generator stamping two bytes does.
        let bytes = Data(
            [0x57, 0x41, 0x52, 0x50, 0x01]
                + Array(repeating: [0x06, 0x01], count: 600).flatMap { pair in pair }
                + [0x00]
        )

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("deeper")
        }
    }

    @Test("text that is not UTF-8 is refused")
    func foreignTextIsRefused() {
        // Given — a lone continuation byte where text was claimed
        let bytes = Data([0x57, 0x41, 0x52, 0x50, 0x01, 0x05, 0x01, 0x80])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("UTF-8")
        }
    }

    @Test("what a document cannot carry is refused on the way out")
    func theUnwritableIsRefusedWhenWriting() {
        // Given — the value model's edges, not this encoding's: these bytes
        // could be written, and the refusal is that no encoding may
        for value in [Value.double(.infinity), .double(.nan)] {
            #expect(throws: (any Error).self) {
                try BinaryEncoding.data(from: value)
            }
        }

        // And code is not data in any encoding
        #expect(throws: (any Error).self) {
            try BinaryEncoding.data(
                from: .procedure(Closure(procedure: Procedure(body: []), captured: Scope()))
            )
        }
    }

    @Test("a fraction that cannot arrive is refused on the way in")
    func theUncarriableIsRefusedWhenReading() {
        // Given — infinity's bit pattern, stamped by hand
        let bytes = Data([
            0x57, 0x41, 0x52, 0x50, 0x01,
            0x04, 0x7f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ])

        #expect {
            try BinaryEncoding.value(from: bytes)
        } throws: { error in
            "\(error)".contains("no way to carry")
        }
    }

    // MARK: - Public
    // MARK: - Private
}
