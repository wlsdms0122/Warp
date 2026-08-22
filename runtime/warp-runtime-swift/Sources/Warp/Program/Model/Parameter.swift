//
//  Parameter.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

public struct Parameter: Sendable, Equatable {
    // MARK: - Property
    // What this takes, or nil where nothing was declared. `any` is a claim that
    // any shape is welcome; nil is the absence of a claim. Neither is checked,
    // and keeping them apart is what lets the ones written on purpose be told
    // from the ones nobody got around to.
    public let type: TypeExpression?
    public let oneOf: [String]?
    public let `default`: Value?
    public let hint: String?

    // A parameter without a default is required — optionality has no separate axis.
    public var isRequired: Bool { `default` == nil }

    // What this reads as where a type is needed regardless. An undeclared
    // parameter accepts what it is handed, which is what `any` says.
    public var declared: TypeExpression { type ?? .any }

    // MARK: - Initializer
    public init(
        type: TypeExpression? = nil,
        oneOf: [String]? = nil,
        default: Value? = nil,
        hint: String? = nil
    ) {
        self.type = type
        self.oneOf = oneOf
        self.default = `default`
        self.hint = hint
    }

    // MARK: - Public
    public func taking(
        _ value: Value,
        called name: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        guard value != .null else {
            guard let fallback = self.default else {
                throw ArgumentError("input '\(name)': required, and nothing was given")
            }

            // The fallback walks through the same gate an argument does, so the
            // body reads the declared representation either way — a default is
            // a value the call left out, not a value the declaration skips.
            return try checking(fallback, called: name, in: types)
        }

        return try checking(value, called: name, in: types)
    }

    public func checking(
        _ value: Value,
        called name: String,
        in types: TypeTable = TypeTable()
    ) throws -> Value {
        if value == .null {
            guard self.default == .null else {
                throw ArgumentError("input '\(name)': expected \(declared), got null")
            }

            return value
        }

        // Settling means the inside reads the declared type — a passing value is
        // normalized to the declared representation, not just waved through, and
        // the walk goes as deep as the declaration does. Undeclared has no
        // representation to normalize to, so the value stands as it arrived.
        let settled = try type.map { type in
            try type.settling(value, at: "input '\(name)'", in: types)
        } ?? value

        if let allowed = oneOf {
            let scalar = Self.scalar(settled)

            guard let scalar, allowed.contains(scalar) else {
                throw ArgumentError(
                    "input '\(name)': '\(scalar ?? "\(settled.type)")' not in oneOf \(allowed)"
                )
            }
        }

        return settled
    }

    // MARK: - Private
    private static func scalar(_ value: Value) -> String? {
        switch value {
        case let .string(string):
            return string

        case let .int(integer):
            return String(integer)

        case let .bool(bool):
            return String(bool)

        case let .double(double):
            return Int(exactly: double).map(String.init) ?? String(double)

        default:
            return nil
        }
    }
}
