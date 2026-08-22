//
//  ExecutionObserver.swift
//  Warp
//
//  Created by JSilver on 8/9/26.
//

import Foundation

// What a run does, as the language sees it: statements bind, and failures are
// either absorbed by an attempt or not. There is no "skipped" event — a
// condition that declines is an expression answering null, and the statement
// that bound it completed like any other.
public protocol ExecutionObserver: Sendable {
    func statementStarted(at trace: Trace, expression: Expression) async
    func statementCompleted(at trace: Trace, result: Value) async
    func statementFailed(at trace: Trace, error: any Error) async

    // The name is the one the failure was bound under while the rescue ran,
    // which is the statement's id wherever a notation writes rescue as an
    // envelope.
    func failureRescued(name: String, error: any Error) async
}

public extension ExecutionObserver {
    func statementStarted(at trace: Trace, expression: Expression) async {
    }

    func statementCompleted(at trace: Trace, result: Value) async {
    }

    func statementFailed(at trace: Trace, error: any Error) async {
    }

    func failureRescued(name: String, error: any Error) async {
    }
}
