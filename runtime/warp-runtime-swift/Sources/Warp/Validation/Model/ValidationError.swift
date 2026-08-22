//
//  ValidationError.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

public struct ValidationError: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    public init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
