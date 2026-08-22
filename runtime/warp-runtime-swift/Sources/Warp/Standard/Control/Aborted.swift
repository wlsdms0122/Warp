//
//  Aborted.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

public struct Aborted: RecoverableFailure {
    // MARK: - Property
    public let message: String

    public var payload: Value {
        .object(["type": .string("aborted"), "message": .string(message)])
    }

    public let trace: Trace?

    // MARK: - Initializer
    public init(_ message: String, trace: Trace? = nil) {
        self.message = message
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> Aborted {
        Aborted(message, trace: trace)
    }

    // MARK: - Private
}
