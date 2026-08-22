//
//  GroupForm.swift
//  WarpDocument
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// A block written as a construct: a body with its own scope, bound to a name
// like anything else.
public struct GroupForm: ConstructForm {
    // MARK: - Property
    public static let key = "group"

    private let block: Block

    // MARK: - Initializer
    public init(from decoder: Decoder) throws {
        self.block = try BlockReader(from: decoder).block
    }

    // MARK: - Public
    public func expression(boundTo id: String?) -> Expression {
        .block(block)
    }

    // MARK: - Private
}
