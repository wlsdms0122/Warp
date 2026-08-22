//
//  BranchForm.swift
//  WarpDocument
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

public struct BranchForm: ConstructForm {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case when
        case then
        case `else`
    }

    // MARK: - Property
    public static let key = "branch"

    // The condition slot reads operators this notation named itself, so the
    // words behind them are owed wherever this form is registered and nowhere
    // else.
    public static func vocabulary(with spellings: SpellingRegistry) -> Set<String> {
        spellings.operatorWords
    }

    private let condition: Expression
    private let then: Block
    private let otherwise: Block?

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "branch")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.condition = try container.decode(ConditionReader.self, forKey: .when).condition
        self.then = try container.decode(BlockReader.self, forKey: .then).block
        self.otherwise = try container.decodeIfPresent(BlockReader.self, forKey: .else)?.block
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        .conditional(condition, then: then, else: otherwise)
    }

    // MARK: - Private
}
