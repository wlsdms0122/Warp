//
//  Trace.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// Where a run is, spelled as everything it went through to get there.
//
// A statement's id names it in the text it was written in, and the same text
// runs more than once — a loop round, a piece of a fan-out, a body called from
// two places. A name alone cannot tell those apart, so nothing outside could say
// which `send` finished, and a language whose account of a run cannot be matched
// up with itself has no account.
//
// Frames are pushed rather than replaced. A run that calls into a body is still
// inside the statement that called it, which is what makes this read like a
// stack rather than a cursor.
//
// It is a list here, and a tree in the whole: a fan-out hands each piece its own
// trace, so what a run leaves behind branches wherever the run did. There is no
// one stack to ask for, and pretending otherwise is what a single mutable
// current-position would do.
public struct Trace: Sendable, Equatable {
    // MARK: - Property
    public let frames: [Frame]

    // How the place reads in a message.
    //
    //   hello.greet.many[2].send
    //
    // Names are joined with dots and occurrences are bracketed, so the spelling
    // says which parts of a place the text decided and which parts the run did.
    public var rendered: String {
        frames.reduce(into: "") { written, frame in
            switch frame {
            case let .procedure(name), let .statement(name):
                written += written.isEmpty ? name : ".\(name)"

            case let .round(index):
                written += "[\(index)]"

            case let .piece(name):
                written += "[\(name)]"
            }
        }
    }

    // MARK: - Initializer
    public init(frames: [Frame] = []) {
        self.frames = frames
    }

    // MARK: - Public
    public func appending(_ frame: Frame) -> Trace {
        Trace(frames: frames + [frame])
    }

    // MARK: - Private
}

extension Trace: CustomStringConvertible {
    public var description: String { rendered }
}
