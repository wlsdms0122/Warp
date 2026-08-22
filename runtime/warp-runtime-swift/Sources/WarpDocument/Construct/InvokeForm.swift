//
//  InvokeForm.swift
//  WarpDocument
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// Calling a value that is a procedure.
//
// Beside `call:` rather than folded into it, because the two ask different
// questions. `call:` names a symbol, and the linker answers it before anything
// runs; this names an expression, and only a run can say what it holds. Writing
// both as one word would hide which of those an author had written.
//
// The spelling is not negotiated with whoever else wants the word. A word belongs
// to a `ConstructRegistry`, so a caller that wants `invoke` for itself removes
// this one and registers its own. Renaming the language to settle an argument
// between two notations is the wrong layer twice over, and `apply` is already an
// operator application in the IR.
public struct InvokeForm: ConstructForm {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case procedure
        case arguments
    }

    // MARK: - Property
    public static let key = "invoke"

    private let callee: Expression
    private let arguments: [String: Expression]

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        try KeyGate().rejectUnknownKeys(in: decoder, known: CodingKeys.self, context: "invoke")

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.callee = try container.decode(ExpressionReader.self, forKey: .procedure).expression
        self.arguments = try container.decodeIfPresent(
            [String: ExpressionReader].self,
            forKey: .arguments
        )?
        .mapValues(\.expression) ?? [:]
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        .invoke(callee, arguments: arguments)
    }

    // MARK: - Private
}
