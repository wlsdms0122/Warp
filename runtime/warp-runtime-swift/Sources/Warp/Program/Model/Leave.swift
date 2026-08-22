//
//  Leave.swift
//  Warp
//
//  Created by JSilver on 8/20/26.
//

import Foundation

// Stopping where you are and carrying on somewhere further out.
//
// It is grammar rather than a word, and the reason is what checking one costs.
// Whether `return 5` is allowed depends on what the procedure it is written in
// declared it answers; whether `break` is allowed depends on there being a loop
// around it. Neither is a fact a signature has a slot for — a word receiving the
// value could only be trusted with it, and a word cannot be told what it is
// written inside.
//
// One case rather than three, because the three differ in how far they go and
// in nothing else.
public struct Leave: Sendable {
    // How far out. `procedure` answers, and the other two are about a loop:
    // `construct` ends it, `round` ends the round it is in.
    public enum Reach: Sendable, Equatable {
        case procedure
        case construct
        case round
    }

    // MARK: - Property
    public let reach: Reach

    // Which loop, where more than one encloses this. Nothing means the nearest,
    // the way it does everywhere else — a name is for reaching past it.
    public let target: String?

    // What a procedure answers by leaving. Only `procedure` carries one: a loop
    // answers what it was going to answer, so ending one early asks nothing new
    // of the type it has.
    public let value: Expression?

    // MARK: - Initializer
    public init(reach: Reach, target: String? = nil, value: Expression? = nil) {
        self.reach = reach
        self.target = target
        self.value = value
    }

    // MARK: - Public
    // MARK: - Private
}
