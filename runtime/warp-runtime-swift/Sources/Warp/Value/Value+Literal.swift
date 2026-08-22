//
//  Value+Literal.swift
//  Warp
//
//  Created by JSilver on 8/18/26.
//

import Foundation

// Writing a value in Swift.
//
// Swift's own literals already spell seven of the eight shapes, and each maps to
// exactly one case, so this is a spelling and not a conversion — `"a"` is
// `.string("a")` for the same reason `"a"` is a `String`. Nothing here reads
// structure out of a string: a path is still `[PathSegment]` and a reference is
// still an `Expression`, because the language does not re-parse text into
// anything live and a convenience is not a reason to start.
//
// Two shapes have no literal. A procedure is made by capturing a scope, which
// happens during a run, so nothing written down can name one.
//
// `null` is spelled `.null` and never `nil`. They are not the same fact — `nil`
// is a slot with nothing in it and `.null` is a value a program computed — and a
// language where a parameter may or may not have a default has to keep them
// apart.
extension Value: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension Value: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension Value: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension Value: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension Value: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Value...) {
        self = .array(elements)
    }
}

// A duplicate key is a mistake being made twice in one literal, and there is no
// value to answer with — the same reaction `Dictionary` has.
extension Value: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Value)...) {
        self = .object(Dictionary(elements) { _, _ in
            preconditionFailure("duplicate key in a value literal")
        })
    }
}
