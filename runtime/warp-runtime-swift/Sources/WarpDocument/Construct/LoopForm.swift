//
//  LoopForm.swift
//  WarpDocument
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// Repetition governed by a condition: the body runs while `where` holds.
// Nothing here bounds a body that never settles — an author bounds a loop with
// a counter and a word, and a receiver stops one with cancellation.
public struct LoopForm: ConstructForm {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case `where`
        case body
        case result
    }

    // MARK: - Property
    public static let key = "loop"

    // The condition slot reads operators this notation named itself, so the
    // words behind them are owed wherever this form is registered and nowhere
    // else.
    public static func vocabulary(with spellings: SpellingRegistry) -> Set<String> {
        spellings.operatorWords
    }

    private let condition: Expression
    private let body: Block

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "loop")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.condition = try container.decode(ConditionReader.self, forKey: .where).condition
        self.body = Block(
            body: try container.decode([StatementReader].self, forKey: .body)
                .map(\.statement),
            result: try container.decodeIfPresent(ExpressionReader.self, forKey: .result)?
                .expression
        )
    }

    // MARK: - Public
    // The round state is bound under the statement's own id, which is how a
    // document writes `${<id>.index}`.
    public func expression(boundTo id: String?) throws -> Expression {
        .loop(while: condition, body: body, round: try named(id, in: "loop", binding: "round"))
    }

    // MARK: - Private
}
