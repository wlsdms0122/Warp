//
//  ValueType.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// What a value is. One case per `Value` case and nothing else — this answers
// about a value in hand, so there is no `any` here and nothing to compose.
//
// What a *declaration* says is `TypeExpression`. The two were one enumeration
// while a declaration could say no more than a value could be; they parted when
// `array<string>` became sayable, and the `any` that never belonged in a value's
// type went with the declarations.
public enum ValueType: String, Sendable, CaseIterable {
    case null
    case bool
    case int
    case double
    case string
    case bytes
    case array
    case object

    // A value that can be called.
    case procedure

    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}

extension ValueType: CustomStringConvertible {
    public var description: String { rawValue }
}
