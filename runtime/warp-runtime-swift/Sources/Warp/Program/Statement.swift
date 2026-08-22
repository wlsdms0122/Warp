//
//  Statement.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// A binding: `id = expression`. That is the only statement the language has,
// because everything else is an expression — `when` is a conditional, `rescue`
// is an attempt, and both are things you bind rather than modifiers you attach
// to an envelope.
//
// What the binding *does* to the name is the second thing a statement says, and
// it is a property of the name rather than a modifier on the statement: a name
// is either fixed, or it is a variable, or this is a write to a variable
// declared earlier.
public struct Statement: Sendable {
    // A name is introduced once and never written again, unless it was
    // introduced as a variable — in which case a later statement may write it,
    // and that write outlives the block it was written in.
    //
    // Keeping the three apart is what lets a body be read: a reader can see
    // which names in it can change, without following every branch to find out.
    public enum Binding: Sendable {
        case constant
        case variable
        case assignment
    }

    // MARK: - Property
    // Nil is a statement run for its effect alone: the construct runs and the
    // answer is dropped. A leaving statement never finishes, so it never has a
    // name — a name that could not bind would be a promise the reader has to
    // remember is false.
    public let id: String?
    public let binding: Binding
    public let expression: Expression

    // MARK: - Initializer
    public init(id: String? = nil, binding: Binding = .constant, expression: Expression) {
        self.id = id
        self.binding = binding
        self.expression = expression
    }

    // MARK: - Public
    // MARK: - Private
}
