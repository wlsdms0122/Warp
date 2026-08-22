//
//  ConcurrentFailed.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// Every piece's failure, keyed by the piece's label. One aggregate rather than
// whichever failure finished first, because which one that is would be timing —
// a rescue reads the same set of failures on every run.
public struct ConcurrentFailed: RecoverableFailure {
    // MARK: - Property
    public let failures: [String: String]

    public var payload: Value {
        .object([
            "type": .string("concurrent_failed"),
            "message": .string(message),
            "failures": .object(failures.mapValues(Value.string))
        ])
    }

    public var message: String {
        "concurrent pieces failed: "
            + failures
                .sorted { left, right in left.key < right.key }
                .map { piece, reason in "\(piece): \(reason)" }
                .joined(separator: "; ")
    }

    public let trace: Trace?

    // MARK: - Initializer
    public init(failures: [String: String], trace: Trace? = nil) {
        self.failures = failures
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> ConcurrentFailed {
        ConcurrentFailed(failures: failures, trace: trace)
    }

    // MARK: - Private
}
