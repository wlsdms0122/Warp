//
//  BinaryEncoding.swift
//  WarpBinary
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Warp

// The encoding a document travels in. This is Warp's own, and it exists because
// the things a wire format must promise are things a borrowed format cannot:
//
// - **A whole number and a fraction are different bytes.** They are different
//   tags, so no general-purpose encoder can collapse them into one kind of
//   number the way a borrowed text format would.
// - **The same document is the same bytes, both ways.** The writer sorts record
//   keys and writes every number minimally, and the reader refuses bytes the
//   writer would not have written — so byte equality and document equality are
//   the same question, which is what makes a document signable and cacheable.
// - **What cannot arrive is refused before it arrives.** Truncation, trailing
//   bytes, an unknown tag, a key out of order — each is a refusal with a name,
//   not a value somebody guessed.
//
// The header carries the *encoding's* version, not the language's. What the
// program needs of its reader is said inside the document (`warp`, `needs`),
// because it is true in every encoding; this byte only says how the bytes
// themselves are laid out.
public enum BinaryEncoding {
    // MARK: - Property
    // "WARP", and then how the bytes are laid out. The version moves when this
    // file's layout does, and for no other reason.
    public static let magic: [UInt8] = [0x57, 0x41, 0x52, 0x50]
    public static let format: UInt8 = 1

    // How deep a reader follows before calling the shape an attack rather than
    // a program. A document is written by a writer that recursed the same way,
    // so an honest one sits nowhere near this.
    static let depth = 512

    private enum Tag: UInt8 {
        case null = 0x00
        case `false` = 0x01
        case `true` = 0x02
        case int = 0x03
        case double = 0x04
        case string = 0x05
        case array = 0x06
        case record = 0x07
        case bytes = 0x08
    }

    // MARK: - Public
    public static func data(from value: Value) throws -> Data {
        var bytes = Data(magic)

        bytes.append(format)

        try write(value, into: &bytes)

        return bytes
    }

    public static func value(from data: Data) throws -> Value {
        var reading = Cursor(data)

        guard reading.take(magic.count).elementsEqual(magic) else {
            throw refused("the bytes do not begin as a warp document begins")
        }

        guard let version = reading.byte() else {
            throw refused("the bytes end before saying how they are laid out")
        }

        guard version == format else {
            throw refused(
                version > format
                    ? "the document is laid out as format \(version), and this reader lays out \(format)"
                    : "format \(version) never existed"
            )
        }

        let value = try read(from: &reading)

        guard reading.isDone else {
            throw refused("the document ended and the bytes did not")
        }

        return value
    }

    // MARK: - Private
    // `within` runs out where the reader's limit runs out, so the writer cannot
    // produce a document its own reader would refuse.
    private static func write(_ value: Value, into bytes: inout Data, within depth: Int = depth) throws {
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
            bytes.append(Tag.null.rawValue)

        case let .bool(bool):
            bytes.append((bool ? Tag.true : Tag.false).rawValue)

        case let .int(int):
            bytes.append(Tag.int.rawValue)

            write(zigzagged(int), into: &bytes)

        case let .double(double):
            // The bytes could carry these; the document's value model cannot,
            // in any encoding — so they are refused rather than becoming a
            // document only this encoding reads.
            guard double.isFinite else {
                throw EncodingError.invalidValue(
                    value,
                    .init(
                        codingPath: [],
                        debugDescription: "a document has no way to carry \(double)"
                    )
                )
            }

            bytes.append(Tag.double.rawValue)

            withUnsafeBytes(of: double.bitPattern.bigEndian) { bytes.append(contentsOf: $0) }

        case let .string(string):
            bytes.append(Tag.string.rawValue)

            write(Array(string.utf8), into: &bytes)

        case let .bytes(raw):
            bytes.append(Tag.bytes.rawValue)

            write(raw, into: &bytes)

        case let .array(array):
            bytes.append(Tag.array.rawValue)

            write(UInt64(array.count), into: &bytes)

            for element in array {
                try write(element, into: &bytes, within: depth - 1)
            }

        // Sorted by their UTF-8 bytes, so that the same document is the same
        // bytes in every implementation. A language's own string ordering is
        // whatever that language decided, and the wire cannot depend on it.
        case let .object(object):
            bytes.append(Tag.record.rawValue)

            write(UInt64(object.count), into: &bytes)

            let fields = object.map { field in (Array(field.key.utf8), field.key, field.value) }
                .sorted { one, other in one.0.lexicographicallyPrecedes(other.0) }

            for (raw, key, value) in fields {
                // A name outside NFC would give one name several byte
                // spellings, and byte order would stop being an order on
                // names — refused on the way out exactly as on the way in.
                guard normal(key) else {
                    throw EncodingError.invalidValue(
                        Value.string(key),
                        .init(
                            codingPath: [],
                            debugDescription: "the field name is not in normal form C"
                        )
                    )
                }

                write(raw, into: &bytes)

                try write(value, into: &bytes, within: depth - 1)
            }

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

    private static func write(_ utf8: [UInt8], into bytes: inout Data) {
        write(UInt64(utf8.count), into: &bytes)

        bytes.append(contentsOf: utf8)
    }

    // Unsigned LEB128: seven bits a byte, low bits first, high bit says another
    // byte follows. The writer never writes a leading zero group, which is what
    // lets the reader treat one as a lie rather than a style.
    private static func write(_ unsigned: UInt64, into bytes: inout Data) {
        var rest = unsigned

        repeat {
            let low = UInt8(rest & 0x7f)

            rest >>= 7

            bytes.append(rest == 0 ? low : low | 0x80)
        } while rest != 0
    }

    // A container being put back together: what it still expects, what it holds
    // so far, and — for a record — the key the next value belongs to and the
    // last key seen, so order can be held without keeping the keys. A sum
    // rather than two optionals, so "neither" and "both" are not states the
    // code has to promise never to reach.
    private enum Opened {
        case array(expecting: Int, held: [Value])
        case record(expecting: Int, held: [String: Value], key: String, previous: [UInt8])
    }

    // One pass over the bytes with an explicit stack, because the depth of a
    // document must never be the depth of the host's call stack — the bytes are
    // the arriving side's, and the stack is ours. The limit that remains is the
    // format's own, and it bounds memory rather than saving the process.
    private static func read(from reading: inout Cursor) throws -> Value {
        var opened: [Opened] = []

        while true {
            guard opened.count <= depth else {
                throw refused("the document nests deeper than a reader must follow")
            }

            guard let raw = reading.byte() else {
                throw refused("the bytes end where a value should begin")
            }

            guard let tag = Tag(rawValue: raw) else {
                throw refused("nothing in this format begins with \(raw)")
            }

            var settled: Value?

            switch tag {
            case .null:
                settled = .null

            case .false:
                settled = .bool(false)

            case .true:
                settled = .bool(true)

            case .int:
                settled = .int(unzigzagged(try unsigned(from: &reading)))

            case .double:
                let raw = reading.take(8)

                guard reading.lastTakeWasComplete else {
                    throw refused("the bytes end inside a fraction")
                }

                let bits = raw.reduce(UInt64(0)) { held, byte in held << 8 | UInt64(byte) }
                let double = Double(bitPattern: bits)

                guard double.isFinite else {
                    throw refused("a document has no way to carry \(double)")
                }

                settled = .double(double)

            case .string:
                settled = .string(try text(from: &reading))

            case .bytes:
                let count = try length(from: &reading, of: "bytes", costing: 1)
                let raw = reading.take(count)

                guard reading.lastTakeWasComplete else {
                    throw refused("the bytes end inside bytes")
                }

                settled = .bytes(Array(raw))

            case .array:
                let count = try length(from: &reading, of: "an array", costing: 1)

                if count == 0 {
                    settled = .array([])
                } else {
                    var held: [Value] = []

                    held.reserveCapacity(count)

                    opened.append(.array(expecting: count, held: held))
                }

            case .record:
                let count = try length(from: &reading, of: "a record", costing: 2)

                if count == 0 {
                    settled = .object([:])
                } else {
                    var held: [String: Value] = [:]

                    held.reserveCapacity(count)

                    let (key, raw) = try field(from: &reading, after: nil)

                    opened.append(.record(expecting: count, held: held, key: key, previous: raw))
                }
            }

            // Hand what settled to whatever is waiting for it, closing every
            // container it completes on the way up.
            while let value = settled {
                guard let open = opened.popLast() else { return value }

                settled = nil

                switch open {
                case .array(let expecting, var held):
                    held.append(value)

                    if expecting == 1 {
                        settled = .array(held)
                    } else {
                        opened.append(.array(expecting: expecting - 1, held: held))
                    }

                case .record(let expecting, var held, let key, let previous):
                    // Unique because the keys arrived strictly ascending and
                    // in NFC: byte order refuses a byte-equal duplicate, and
                    // NFC leaves one name one byte spelling to be equal in.
                    held[key] = value

                    if expecting == 1 {
                        settled = .object(held)
                    } else {
                        let (next, raw) = try field(from: &reading, after: previous)

                        opened.append(
                            .record(expecting: expecting - 1, held: held, key: next, previous: raw)
                        )
                    }
                }
            }
        }
    }

    // The next field a record waits for. Strictly ascending, which refuses a
    // duplicate and a shuffle with the same sentence: these are bytes the
    // writer would not write. NFC, so that byte order is an order on names —
    // a name with a second byte spelling would sort to a second place.
    private static func field(
        from reading: inout Cursor,
        after previous: [UInt8]?
    ) throws -> (String, [UInt8]) {
        let key = try text(from: &reading)
        let raw = Array(key.utf8)

        if let previous, !previous.lexicographicallyPrecedes(raw) {
            throw refused("the record's keys are not written in order")
        }

        guard normal(key) else {
            throw refused("the field name is not in normal form C")
        }

        return (key, raw)
    }

    // Whether a name is its own NFC form, by bytes — Swift's own `==` compares
    // under canonical equivalence, which is exactly the difference this rule
    // exists to see. ASCII always passes.
    private static func normal(_ name: String) -> Bool {
        Name.isNormal(name)
    }

    private static func text(from reading: inout Cursor) throws -> String {
        let count = try length(from: &reading, of: "text", costing: 1)

        let bytes = reading.take(count)

        guard reading.lastTakeWasComplete else {
            throw refused("the bytes end inside text")
        }

        guard let string = String(bytes: bytes, encoding: .utf8) else {
            throw refused("the text is not UTF-8")
        }

        return string
    }

    // A claimed length, charged against the one budget all claims share: the
    // bytes of the document itself. Each claimed thing costs at least `cost`
    // bytes to actually write, so however deeply the claimants nest, their
    // claims cannot sum past the document — a check against only the bytes
    // *remaining* was local to each claim, and five hundred nested containers
    // could each claim the whole document and have memory set aside for it.
    private static func length(
        from reading: inout Cursor,
        of what: String,
        costing cost: Int
    ) throws -> Int {
        let claimed = try unsigned(from: &reading)

        guard claimed <= UInt64(Int.max), reading.claim(Int(claimed), costing: cost) else {
            throw refused("\(what) claims more than the document holds")
        }

        return Int(claimed)
    }

    private static func unsigned(from reading: inout Cursor) throws -> UInt64 {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var last: UInt8 = 0

        while true {
            guard let byte = reading.byte() else {
                throw refused("the bytes end inside a number")
            }

            guard shift < 64, shift < 63 || byte <= 0x01 else {
                throw refused("the number does not fit in 64 bits")
            }

            value |= UInt64(byte & 0x7f) << shift
            last = byte

            guard byte & 0x80 != 0 else { break }

            shift += 7
        }

        // A trailing zero group is a longer spelling of the same number, and a
        // canonical wire has one spelling.
        guard shift == 0 || last != 0 else {
            throw refused("the number is written longer than it is")
        }

        return value
    }

    // ZigZag: small magnitudes of either sign become small unsigned numbers, so
    // the varint stays short for the numbers programs actually hold.
    private static func zigzagged(_ int: Int) -> UInt64 {
        UInt64(bitPattern: Int64(int) << 1 ^ (Int64(int) >> 63))
    }

    private static func unzigzagged(_ unsigned: UInt64) -> Int {
        Int(truncatingIfNeeded: Int64(bitPattern: unsigned >> 1 ^ (0 &- (unsigned & 1))))
    }

    private static func refused(_ said: String) -> Error {
        DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: said))
    }

    // A place in the bytes. `take` answers what it can and remembers whether
    // that was everything asked for, so a caller checks the one fact it needs.
    private struct Cursor {
        private let bytes: [UInt8]
        private var index = 0

        // What the document's claims may still spend, together. Every approved
        // claim charges what it would minimally cost to write, so the total
        // that can ever be set aside is bounded by the bytes that arrived.
        private var budget: Int

        var remaining: Int { bytes.count - index }
        var isDone: Bool { remaining == 0 }
        private(set) var lastTakeWasComplete = true

        init(_ data: Data) {
            bytes = [UInt8](data)
            budget = bytes.count
        }

        mutating func claim(_ count: Int, costing cost: Int) -> Bool {
            let charged = count.multipliedReportingOverflow(by: cost)

            guard !charged.overflow, charged.partialValue <= budget else { return false }

            budget -= charged.partialValue

            return true
        }

        mutating func byte() -> UInt8? {
            guard index < bytes.count else { return nil }

            defer { index += 1 }

            return bytes[index]
        }

        mutating func take(_ count: Int) -> ArraySlice<UInt8> {
            let end = Swift.min(index + count, bytes.count)

            defer {
                lastTakeWasComplete = end - index == count
                index = end
            }

            return bytes[index..<end]
        }
    }
}
