//
//  WritingError.swift
//  WarpDocument
//
//  Created by JSilver on 8/20/26.
//

import Foundation
import Warp

// A program shape this notation has no words for.
//
// It is worth having as its own kind of refusal. A notation is a table of
// spellings and a set of forms, so what it cannot say is a fact about that
// table — and the only way to find out what a table leaves unsaid is to try to
// write every shape through it.
public struct WritingError: WarpError {
    // MARK: - Property
    public let message: String

    // MARK: - Initializer
    public init(_ message: String) {
        self.message = message
    }

    // MARK: - Public
    // MARK: - Private
}
