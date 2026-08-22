//
//  Leaving.swift
//  Warp
//
//  Created by JSilver on 8/20/26.
//

import Foundation

// A run on its way somewhere further out.
//
// It travels the way a failure does because the shape is the same — everything
// between here and where it lands is abandoned — but it is not a failure, and
// the difference is load-bearing: `attempt` catches what the world did, and this
// is what the program said. Leaving a body an `attempt` was watching runs no
// rescue, which is the whole reason the language needed this and could not go on
// borrowing the failure channel to say it.
//
// Nothing catches it but the construct it names. Reaching a boundary that does
// not answer to it is impossible rather than unhandled: a body may only write
// one that something around it will catch, and the validator settles that before
// anything runs.
struct Leaving: Error {
    // MARK: - Property
    let reach: Leave.Reach
    let target: String?

    // What a procedure answers by leaving. A loop answers what it was going to
    // answer, so this is nothing for the other two reaches.
    let value: Value

    // MARK: - Initializer
    init(reach: Leave.Reach, target: String?, value: Value = .null) {
        self.reach = reach
        self.target = target
        self.value = value
    }

    // MARK: - Public
    // Whether a loop should take this. An unnamed one is for the nearest, so the
    // first loop it reaches answers it; a named one passes through every loop
    // but the one it named.
    func claimed(by round: String) -> Bool {
        guard reach != .procedure else { return false }

        return target == nil || target == round
    }

    // MARK: - Private
}
