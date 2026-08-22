//
//  MappingQuery.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// Reading an object as data rather than as a shape. A record's fields are
// declared and read by name; an object's are data, and these are how a program
// walks them without knowing what they are called.
//
// `setting` answers a new object, so an author writes a changed mapping without
// the language growing a way to write into one.
public struct MappingQuery: Query {
    public enum Reading: Sendable {
        case keys
        case values
        case setting
    }

    // MARK: - Property
    private let reading: Reading

    // MARK: - Initializer
    public init(_ reading: Reading) {
        self.reading = reading
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard case let .object(fields) = question.receiver else { return nil }

        switch reading {
        // Sorted, because an object holds no order of its own and a walk that
        // answered a different order each run would make a program that reads it
        // depend on nothing an author wrote.
        case .keys:
            return .array(fields.keys.sorted().map(Value.string))

        case .values:
            return .array(fields.keys.sorted().compactMap { key in fields[key] })

        case .setting:
            guard case let .string(key) = question["key"] else {
                throw ExecutionError("setting asks a string key")
            }

            return .object(fields.merging([key: question["value"]]) { _, new in new })
        }
    }

    // MARK: - Private
}
