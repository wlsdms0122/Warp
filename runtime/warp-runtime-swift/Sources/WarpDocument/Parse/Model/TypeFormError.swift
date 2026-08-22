//
//  TypeFormError.swift
//  WarpDocument
//
//  Created by JSilver on 8/17/26.
//

import Foundation
import Warp

// A type spelled in a way this notation cannot read. About the writing, not
// about the language — whether the shape it names exists is a link question.
public struct TypeFormError: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    public init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
