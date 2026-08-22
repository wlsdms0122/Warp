//
//  WarpError.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// Everything this language refuses with says one sentence about why. No area
// owns that — validation, linking, the runtime and the notation reader all
// declare it — so it sits at the root beside `Language` rather than being
// filed under whichever of them is asked to keep it.
public protocol WarpError: Error, Sendable, CustomStringConvertible {
    var message: String { get }

    // Where the run was when this was refused. A sentence is written where the
    // mistake is noticed and nothing there is holding a place, so the place goes
    // on as the failure leaves the statement it happened in — and the innermost
    // one stays, because a statement further out is where the run was rather
    // than where the mistake is.
    var trace: Trace? { get }

    func tracing(_ trace: Trace) -> Self
}

public extension WarpError {
    var description: String {
        guard let trace else { return message }

        return "\(trace.rendered): \(message)"
    }

    // What refuses before a run has nowhere to have been, and says where it is
    // in the sentence instead.
    var trace: Trace? { nil }

    func tracing(_ trace: Trace) -> Self { self }
}
