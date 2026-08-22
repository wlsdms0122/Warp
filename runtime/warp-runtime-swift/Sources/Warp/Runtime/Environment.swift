//
//  Environment.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What a caller hands one run: the services its own words reach for, and
// whatever else only that caller knows about. The language never reads it; an
// effect recognises its own environment and takes it from here.
public protocol Environment: Sendable {
    // A fan-out is an isolation boundary for the caller as much as for the
    // language. Ambient state a caller carries on the task — a task local holding
    // an open session, say — would otherwise reach every piece at once, and
    // siblings would share one conversation. This is where that state is severed
    // or forked. The language stays ignorant of what the state is.
    //
    // It lives here, with a default, rather than in a protocol a caller may or
    // may not adopt. A refinement is only found by callers that already know to
    // look for it, so the ones that need it most — the ones that never thought
    // about ambient state — get silence and a wrong answer. A method everyone
    // sees and may ignore is a decision; an optional cast is a trapdoor.
    func isolateConcurrentWork<T: Sendable>(
        _ work: @Sendable () async throws -> T
    ) async throws -> T
}

public extension Environment {
    // Running the work as it stands. Correct for any caller that carries no
    // ambient state, which is most of them.
    func isolateConcurrentWork<T: Sendable>(
        _ work: @Sendable () async throws -> T
    ) async throws -> T {
        try await work()
    }
}
