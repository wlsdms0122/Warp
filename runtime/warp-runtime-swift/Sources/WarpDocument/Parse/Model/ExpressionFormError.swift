//
//  ExpressionFormError.swift
//  WarpDocument
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

// A malformed expression form — thrown during Value→expression interpretation
// and wrapped into DecodingError at the Codable boundary.
public struct ExpressionFormError: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    public init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
