//
//  AttemptForm.swift
//  WarpDocument
//
//  Created by JSilver on 8/16/26.
//

import Foundation
import Warp

// A body run under a rescue. What it guards is a body rather than a statement,
// so an author writes the span they mean instead of marking each statement in
// it.
//
// While the rescue runs, the failure is a value under the attempt's own name.
public struct AttemptForm: ConstructForm {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case body
        case result
        case rescue
    }

    // MARK: - Property
    public static let key = "attempt"

    private let attempted: Block
    private let rescue: Block

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "attempt")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.attempted = Block(
            body: try container.decode([StatementReader].self, forKey: .body)
                .map(\.statement),
            result: try container.decodeIfPresent(ExpressionReader.self, forKey: .result)?
                .expression
        )
        self.rescue = try container.decode(BlockReader.self, forKey: .rescue).block

        // An empty rescue would swallow a failure into null without a trace — if
        // the alternate path produces nothing, the honest form is no attempt.
        guard !rescue.body.isEmpty || rescue.result != nil else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "attempt `rescue` must not be empty"
                )
            )
        }
    }

    // MARK: - Public
    public func expression(boundTo id: String?) throws -> Expression {
        .attempt(attempted, rescue: rescue, failure: try named(id, in: "attempt", binding: "failure"))
    }

    // MARK: - Private
}
