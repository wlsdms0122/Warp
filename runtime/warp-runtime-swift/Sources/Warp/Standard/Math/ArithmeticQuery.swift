//
//  ArithmeticQuery.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// The numeric operations, as one implementation with the operation as its data.
// A name belongs to the declaration, so several declarations share one of these.
//
// Ints stay ints, so `2 plus 2` answers 4 rather than 4.0. Division is the
// exception, because a quotient is not generally whole — `remainder` is where a
// whole division's other half is read.
//
// Whole arithmetic refuses rather than traps. An answer that does not fit an int
// and a divisor of zero are both things a program can be handed at run time, so
// they leave through the failure channel an `attempt` can catch instead of
// taking the process with them.
public struct ArithmeticQuery: Query {
    public enum Operation: Sendable {
        case plus
        case minus
        case times
        case dividedBy
        case remainder
        case min
        case max
    }

    // MARK: - Property
    private let operation: Operation

    // MARK: - Initializer
    public init(_ operation: Operation) {
        self.operation = operation
    }

    // MARK: - Public
    public func evaluate(_ question: Question) throws -> Value? {
        let operand = question["value"]

        guard let left = number(question.receiver), let right = number(operand) else {
            throw ExecutionError(
                "arithmetic asks \(question.receiver?.type.description ?? "nothing") and"
                    + " \(operand.type), expected two numbers"
            )
        }

        guard !divides || right != 0 else {
            throw ExecutionError("\(operation) asks zero")
        }

        if
            case let .int(leftWhole) = question.receiver,
            case let .int(rightWhole) = operand,
            operation != .dividedBy
        {
            return .int(try whole(leftWhole, rightWhole))
        }

        let answered = real(left, right)

        // The same line the whole path holds. Infinity is a fraction the
        // arithmetic can reach and no document can carry, so answering it would
        // mint a value that exists only until someone writes it down.
        guard answered.isFinite else {
            throw ExecutionError(
                "\(operation) of \(left) and \(right) has no finite answer"
            )
        }

        return .double(answered)
    }

    // MARK: - Private
    // Whether a zero on the right has no answer. Both read a divisor, and both
    // are asked before the whole path so the check cannot be walked around.
    private var divides: Bool {
        operation == .dividedBy || operation == .remainder
    }

    private func whole(_ left: Int, _ right: Int) throws -> Int {
        let answered: (partialValue: Int, overflow: Bool)

        switch operation {
        case .plus:
            answered = left.addingReportingOverflow(right)

        case .minus:
            answered = left.subtractingReportingOverflow(right)

        case .times:
            answered = left.multipliedReportingOverflow(by: right)

        case .dividedBy:
            answered = left.dividedReportingOverflow(by: right)

        case .remainder:
            answered = left.remainderReportingOverflow(dividingBy: right)

        case .min:
            answered = (Swift.min(left, right), false)

        case .max:
            answered = (Swift.max(left, right), false)
        }

        guard !answered.overflow else {
            throw ExecutionError(
                "\(operation) of \(left) and \(right) has no whole answer"
            )
        }

        return answered.partialValue
    }

    private func real(_ left: Double, _ right: Double) -> Double {
        switch operation {
        case .plus:
            return left + right

        case .minus:
            return left - right

        case .times:
            return left * right

        case .dividedBy:
            return left / right

        // Truncating toward zero, the same as the whole answer — a wrap written
        // over doubles reads the way the same wrap written over ints does.
        case .remainder:
            return left.truncatingRemainder(dividingBy: right)

        case .min:
            return Swift.min(left, right)

        case .max:
            return Swift.max(left, right)
        }
    }

    private func number(_ value: Value?) -> Double? {
        switch value {
        case let .int(whole):
            return Double(whole)

        case let .double(real):
            return real

        default:
            return nil
        }
    }
}

extension ArithmeticQuery.Operation: Equatable {
}
