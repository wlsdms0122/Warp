//
//  BlockReader.swift
//  WarpDocument
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// `body:` and `result:` — the pair every construct that runs a body writes.
public struct BlockReader: Decodable {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case body
        case result
    }

    // MARK: - Property
    public let block: Block

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "block")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.block = Block(
            body: try container.decodeIfPresent([StatementReader].self, forKey: .body)?
                .map(\.statement) ?? [],
            result: try container.decodeIfPresent(ExpressionReader.self, forKey: .result)?
                .expression
        )
    }

    // MARK: - Public
    // MARK: - Private
}
