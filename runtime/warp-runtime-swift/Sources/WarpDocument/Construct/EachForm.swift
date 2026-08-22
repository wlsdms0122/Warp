//
//  EachForm.swift
//  WarpDocument
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// The material ends this repetition — one round per element, so termination is
// structural and no budget exists. A walk answers nothing: a pure mapping is
// `std.collection.map`'s to say, and an effectful round with something to keep
// writes it to an outer variable.
public struct EachForm: ConstructForm {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case `in`
        case body
    }

    // MARK: - Property
    public static let key = "each"

    private let material: Expression
    private let body: [Statement]

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "each")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.material = try container.decode(ExpressionReader.self, forKey: .in).expression
        self.body = try container.decode([StatementReader].self, forKey: .body)
            .map(\.statement)
    }

    // MARK: - Public
    // The element is bound under the statement's own id, which is how a document
    // writes `${<id>.item}` and `${<id>.index}`.
    public func expression(boundTo id: String?) throws -> Expression {
        .iteration(over: material, body: body, element: try named(id, in: "each", binding: "element"))
    }

    // MARK: - Private
}
