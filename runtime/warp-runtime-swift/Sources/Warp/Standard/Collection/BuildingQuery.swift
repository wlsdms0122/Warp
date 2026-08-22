//
//  BuildingQuery.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// Making an array out of another one. Nothing is written in place: each answers
// a new array, which is what a language whose names are fixed by default can
// offer.
//
// Without these an array's length is whatever the text wrote down, because the
// only other way to build one is `each`, which answers one element for every
// element it was given.
public struct BuildingQuery: Query {
    public enum Building: Sendable {
        case appending
        case prepending
        case dropFirst
        case dropLast
        case sorted
    }

    // MARK: - Property
    private let building: Building

    // MARK: - Initializer
    public init(_ building: Building) {
        self.building = building
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        guard case let .array(elements) = question.receiver else { return nil }

        switch building {
        case .appending:
            return .array(elements + [question["value"]])

        case .prepending:
            return .array([question["value"]] + elements)

        // Dropping from an array that has nothing left answers the empty array
        // rather than failing: taking none of nothing is nothing.
        case .dropFirst:
            return .array(Array(elements.dropFirst()))

        case .dropLast:
            return .array(Array(elements.dropLast()))

        case .sorted:
            return .array(try sorted(elements))
        }
    }

    // MARK: - Private
    // Numbers order among themselves and strings among themselves. A mixed array
    // has no order this could answer with, so it says so rather than picking one.
    private func sorted(_ elements: [Value]) throws -> [Value] {
        if let numbers = elements.map(number).allSatisfying() {
            return zip(numbers, elements)
                .sorted { left, right in left.0 < right.0 }
                .map(\.1)
        }

        if let strings = elements.map(string).allSatisfying() {
            return zip(strings, elements)
                .sorted { left, right in left.0 < right.0 }
                .map(\.1)
        }

        guard elements.isEmpty else {
            throw ExecutionError(
                "sorted asks an array of numbers or an array of strings"
            )
        }

        return elements
    }

    private func number(_ value: Value) -> Double? {
        switch value {
        case let .int(whole):
            return Double(whole)

        case let .double(real):
            return real

        default:
            return nil
        }
    }

    private func string(_ value: Value) -> String? {
        guard case let .string(text) = value else { return nil }

        return text
    }
}

private extension Array {
    // The whole list, or nothing, where every element is present.
    func allSatisfying<Wrapped>() -> [Wrapped]? where Element == Wrapped? {
        let present = compactMap { $0 }

        return present.count == count && !isEmpty ? present : nil
    }
}
