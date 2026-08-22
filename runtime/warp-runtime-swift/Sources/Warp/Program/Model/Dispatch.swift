//
//  Dispatch.swift
//  Warp
//
//  Created by JSilver on 8/16/26.
//

import Foundation

// A message: a selector, what it is sent to, and what it is sent with.
//
// The language has one calling shape and leaves the question of what answers to
// the link. A procedure, a bundled word and a caller's own are not three kinds
// of expression — they are three places a selector can be found, and where it
// was found is a linkage fact rather than something the author wrote down. So
// every one of them lowers to this, and a caller adds a word without the grammar
// growing a case.
//
// The receiver is optional because not every message has one. `x.count` and
// `{ of: x, contains: y }` are sent *to* something; a procedure call is not. The
// language declines to invent a receiver for the ones that have none.
public struct Dispatch: Sendable {
    // MARK: - Property
    public let receiver: Expression?
    public let selector: String
    public let arguments: [String: Expression]

    // MARK: - Initializer
    public init(
        receiver: Expression? = nil,
        selector: String,
        arguments: [String: Expression] = [:]
    ) {
        self.receiver = receiver
        self.selector = selector
        self.arguments = arguments
    }

    // MARK: - Public
    // MARK: - Private
}
