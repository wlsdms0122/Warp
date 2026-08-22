//
//  NumberQuery.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// The readings of a single number. Each takes nothing beyond its receiver, so
// each is reachable from a path.
//
// `floored` and `rounded` answer an int whatever they were sent, which is how a
// quotient becomes a whole number again — `dividedBy` always answers a double,
// and this is the other half of writing a whole division. A double with no whole
// answer refuses rather than traps: infinity and anything past what an int holds
// arrive at run time, and taking the process with them is not an answer.
public struct NumberQuery: Query {
    public enum Reading: Sendable {
        case absolute
        case floored
        case rounded
    }

    // MARK: - Property
    private let reading: Reading

    // MARK: - Initializer
    public init(_ reading: Reading) {
        self.reading = reading
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        switch (reading, question.receiver) {
        case let (.absolute, .int(number)):
            let answered = number.magnitude

            guard let held = Int(exactly: answered) else {
                throw ExecutionError("\(number) without its sign is past what an int holds")
            }

            return .int(held)

        case let (.absolute, .double(real)):
            return .double(abs(real))

        case let (.floored, .int(whole)), let (.rounded, .int(whole)):
            return .int(whole)

        case let (.floored, .double(real)):
            return .int(try whole(real.rounded(.down), from: real))

        case let (.rounded, .double(real)):
            return .int(try whole(real.rounded(), from: real))

        default:
            return nil
        }
    }

    // MARK: - Private
    private func whole(_ rounded: Double, from asked: Double) throws -> Int {
        guard let answered = Int(exactly: rounded) else {
            throw ExecutionError("\(asked) has no whole answer an int can hold")
        }

        return answered
    }
}
