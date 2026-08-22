//
//  ReferenceUnfit.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

public struct ReferenceUnfit: WarpError {
    // MARK: - Property
    public let path: [PathSegment]
    public let reason: String

    public var message: String {
        "reference unfit: { ref: \(path.rendered) } — \(reason)"
    }

    public let trace: Trace?

    // MARK: - Initializer
    public init(path: [PathSegment], reason: String, trace: Trace? = nil) {
        self.path = path
        self.reason = reason
        self.trace = trace
    }

    // MARK: - Public
    public func tracing(_ trace: Trace) -> ReferenceUnfit {
        ReferenceUnfit(path: path, reason: reason, trace: trace)
    }

    // MARK: - Private
}
