//
//  CallForm.swift
//  WarpDocument
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// Calling a procedure by name.
//
// A call names a symbol, never a document. Naming the document would write a
// linkage fact into the call site; which module declared it is the linker's
// business.
//
// It is a construct key rather than the bare name a native word is written
// under, because a construct key is read at decode time and a procedure's name
// is not in the registry then — it is not known until the link. A name only
// known after linking cannot be a construct key, and this word is what that
// costs.
//
// A body a word is to run travels as a closure argument like any other value —
// a call carries no body of its own kind. One channel, one rule: what crosses
// into a word is isolated.
public struct CallForm: ConstructForm {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case procedure
        case of
        case arguments
    }

    // MARK: - Property
    public static let key = "call"

    private let procedure: String
    private let receiver: Expression?
    private let arguments: [String: Expression]

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "call")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.procedure = try container.decode(String.self, forKey: .procedure)
        self.receiver = try container.decodeIfPresent(ExpressionReader.self, forKey: .of)?
            .expression
        self.arguments = try container.decodeIfPresent(
            [String: ExpressionReader].self,
            forKey: .arguments
        )?
        .mapValues(\.expression) ?? [:]
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        .dispatch(
            Dispatch(
                receiver: receiver,
                selector: procedure,
                arguments: arguments
            )
        )
    }

    // MARK: - Private
}
