//
//  Value.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// What a program computes over. Eight data shapes and one that is not data: a
// procedure is a value here, so a body can be passed, kept and answered with.
//
// Equality is written by hand because a procedure has no honest one: two
// procedures are never equal, and identity is not a question this language lets
// you ask.
public indirect enum Value: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case bytes([UInt8])
    case array([Value])
    case object([String: Value])
    case procedure(Closure)

    // MARK: - Property
    public var type: ValueType {
        switch self {
        case .null:
            return .null

        case .bool:
            return .bool

        case .int:
            return .int

        case .double:
            return .double

        case .string:
            return .string

        case .bytes:
            return .bytes

        case .array:
            return .array

        case .object:
            return .object

        case .procedure:
            return .procedure
        }
    }

    // A field of a record, and nil for anything else. Several answers travel as
    // one record because a procedure answers one value, so reading a field back
    // out is the ordinary thing a caller does with what a run gave it.
    public subscript(field: String) -> Value? {
        guard case let .object(object) = self else { return nil }

        return object[field]
    }

    // MARK: - Initializer
    // MARK: - Public
    public static func == (lhs: Value, rhs: Value) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null):
            return true

        case let (.bool(left), .bool(right)):
            return left == right

        case let (.int(left), .int(right)):
            return left == right

        case let (.double(left), .double(right)):
            return left == right

        case let (.string(left), .string(right)):
            return left == right

        // Bytes are not text: no encoding is assumed, so equality is the
        // bytes themselves and no Unicode rule applies.
        case let (.bytes(left), .bytes(right)):
            return left == right

        case let (.array(left), .array(right)):
            return left == right

        case let (.object(left), .object(right)):
            return left == right

        // Two procedures are never equal. Structural equality would compare
        // bodies, which says nothing an author asked about, and reference
        // equality would make a value's identity observable — neither is a
        // question this language has.
        case (.procedure, .procedure):
            return false

        default:
            return false
        }
    }

    // The equality conditions test with — strict except that int and double unify
    // across numeric width, applied recursively through arrays and objects.
    public func matches(_ other: Value) -> Bool {
        switch (self, other) {
        case let (.int(left), .double(right)):
            return Double(left) == right

        case let (.double(left), .int(right)):
            return left == Double(right)

        case let (.array(left), .array(right)):
            return left.count == right.count
                && zip(left, right).allSatisfy { pair in pair.0.matches(pair.1) }

        case let (.object(left), .object(right)):
            return left.count == right.count
                && left.allSatisfy { key, value in
                    right[key].map { other in value.matches(other) } ?? false
                }

        default:
            return self == other
        }
    }

    // MARK: - Private
}
