//
//  AnyCodingKey.swift
//  WarpDocument
//
//  Created by JSilver on 8/15/26.
//

import Foundation
import Warp

// A key that accepts whatever a container actually holds, so that the keys a
// type does not declare can be seen rather than silently skipped.
struct AnyCodingKey: CodingKey {
    // MARK: - Property
    let stringValue: String

    var intValue: Int? { nil }

    // MARK: - Initializer
    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }

    // MARK: - Public
    // MARK: - Private
}
