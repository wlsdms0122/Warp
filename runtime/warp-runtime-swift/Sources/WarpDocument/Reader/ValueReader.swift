//
//  ValueReader.swift
//  WarpDocument
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// Data as a document spells it. `Value` is the language's data type and knows
// nothing about being written down; this is the one place that mapping lives.
public struct ValueReader: Decodable {
    // MARK: - Property
    public let value: Value

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = .null

            return
        }

        if let bool = try? container.decode(Bool.self) {
            self.value = .bool(bool)

            return
        }

        if let integer = try? container.decode(Int.self) {
            self.value = .int(integer)

            return
        }

        if let double = try? container.decode(Double.self) {
            self.value = .double(double)

            return
        }

        if let string = try? container.decode(String.self) {
            self.value = .string(string)

            return
        }

        // Bytes come over whole, as `Data` — and only across the Value
        // bridge, which answers `Data` for the bytes kind alone. A foreign
        // decoder is never asked: this projection's writer has no spelling for
        // bytes, so its reader reads none — the pair stays one set of values —
        // and a foreign decoder's own `Data` reading could quietly turn an
        // array of small numbers into bytes.
        if decoder is ValueDecoder, let data = try? container.decode(Data.self) {
            self.value = .bytes([UInt8](data))

            return
        }

        if let array = try? container.decode([ValueReader].self) {
            self.value = .array(array.map(\.value))

            return
        }

        if let object = try? container.decode([String: ValueReader].self) {
            self.value = .object(object.mapValues(\.value))

            return
        }

        throw DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Value could not be decoded"
            )
        )
    }

    // MARK: - Public
    // MARK: - Private
}
