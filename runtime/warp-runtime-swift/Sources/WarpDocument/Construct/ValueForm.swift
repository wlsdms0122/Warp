//
//  ValueForm.swift
//  WarpDocument
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// `value:` is the adapter that lets an expression stand where a statement is
// written. In the IR there is nothing to adapt — an expression bound to a name
// is already a statement — so this form carries the expression through.
public struct ValueForm: ConstructForm {
    // MARK: - Property
    public static let key = "value"

    private let value: Expression

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        self.value = try ExpressionReader(from: decoder).expression
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        value
    }

    // MARK: - Private
}
