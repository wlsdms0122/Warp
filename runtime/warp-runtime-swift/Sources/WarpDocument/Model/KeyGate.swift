//
//  KeyGate.swift
//  WarpDocument
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

public struct KeyGate {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    public func rejectUnknownKeys<K: CodingKey & CaseIterable>(
        in decoder: Decoder,
        known: K.Type,
        extra: [String] = [],
        context: String
    ) throws {
        try rejectUnknownKeys(
            in: decoder,
            known: K.allCases.map(\.stringValue) + extra,
            context: context
        )
    }

    public func rejectUnknownKeys(
        in decoder: Decoder,
        known: [String],
        context: String
    ) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        let unknown = container.allKeys
            .map(\.stringValue)
            .filter { key in !known.contains(key) }

        guard unknown.isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "\(context): unknown key(s)"
                        + " \(unknown.sorted().joined(separator: ", "))"
                        + " — known keys: \(known.sorted().joined(separator: ", "))"
                )
            )
        }
    }

    // MARK: - Private
}
