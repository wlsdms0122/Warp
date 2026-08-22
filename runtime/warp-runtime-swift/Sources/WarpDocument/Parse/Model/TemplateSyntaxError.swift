//
//  TemplateSyntaxError.swift
//  WarpDocument
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

public struct TemplateSyntaxError: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    public init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
