//
//  ExecutionError.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

public struct ExecutionError: WarpError {
    // MARK: - Property
    public let message: String

    public let trace: Trace?

    // MARK: - Initializer
    public init(_ message: String, trace: Trace? = nil) {
        self.message = message
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> ExecutionError {
        ExecutionError(message, trace: trace)
    }

    // MARK: - Private
}
