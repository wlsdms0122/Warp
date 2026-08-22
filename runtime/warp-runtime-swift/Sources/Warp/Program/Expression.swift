//
//  Expression.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Everything that computes. Control flow is here rather than beside it: a
// construct that runs a body still answers with a value, and `id: <construct>`
// is how that value gets a name.
//
// The data shapes:
//
//   literal    — a `Value`, verbatim. The type system already says what data
//                is, so an expression does not restate it
//   reference  — a name to resolve in the consuming scope. A name the scope
//                does not hold reads as null
//   array      — elements are expressions
//   record     — fields are expressions
//   dispatch   — a message: a selector, a receiver, arguments. The one calling
//                shape, and the only open one
//
// The control shapes carry a `Block` and, where a name has to exist inside that
// block, the name itself — so an expression means the same thing wherever it
// appears, instead of borrowing the id of whatever bound it.
//
// `dispatch` is the one open case. A procedure, a bundled word and a caller's
// own all lower to it, because they differ only in where the selector is found —
// and finding it is the link's job, not the grammar's.
//
// There is no operator here. Equality, negation and the connectives are words
// like any other, so the grammar says what a program *is* and never what one
// computes. A connective declines to ask its later sides by taking procedures
// rather than values, which is a thing a declaration can say.
//
// How a document writes any of this is `WarpDocument`.
public indirect enum Expression: Sendable {
    case literal(Value)
    case reference([PathSegment])
    case array([Expression])
    case record([String: Expression])

    // A procedure written where a value is wanted. Evaluating it captures the
    // scope it was written in, which is the whole of what makes it a closure.
    case closure(Procedure)

    // Calling a value rather than a name. `dispatch` asks a table and a call
    // graph what a selector means, and the linker settles that before any run;
    // this asks the value in hand, and only a run can. Two spellings because
    // they are two questions: fusing them would mean a local name could quietly
    // stand in for a linked one, and linking would stop being a promise.
    case invoke(Expression, arguments: [String: Expression])

    case block(Block)
    case conditional(Expression, then: Block, else: Block?)
    // Repetition carries no budget of its own. Bounding a loop is the author's
    // to write — a counter and `std.control.abort` say it exactly — and
    // stopping one is the receiver's cancellation; a kernel budget would
    // promise neither side anything it can rely on.
    case loop(while: Expression, body: Block, round: String)
    // The one repetition whose body is statements alone — a walk answers
    // nothing. A pure mapping is `std.collection.map`'s to say; an effectful
    // round with something to keep writes it to an outer variable. Either
    // way, nothing is the walk's own answer.
    case iteration(over: Expression, body: [Statement], element: String)
    case attempt(Block, rescue: Block, failure: String)
    case dispatch(Dispatch)

    // Carrying on somewhere further out than the next statement. The one shape
    // that never even finishes: what comes after it in its body does not run,
    // so a body may not have anything after it.
    case leave(Leave)

    // MARK: - Property
    // The path of a plain reference — an effect that requires one names it
    // through this.
    public var referencePath: [PathSegment]? {
        guard case let .reference(path) = self else { return nil }

        return path
    }

    // The value of an expression that needs no scope. Nil the moment any part
    // must resolve at run time. Load-time gates — an atom validating its literal
    // operand, the linker judging a constant argument — use this to judge what
    // can be judged before any run.
    public var constantValue: Value? {
        switch self {
        case let .literal(value):
            return value

        case let .array(array):
            let values = array.compactMap(\.constantValue)

            return values.count == array.count ? .array(values) : nil

        case let .record(record):
            let values = record.compactMapValues(\.constantValue)

            return values.count == record.count ? .object(values) : nil

        default:
            return nil
        }
    }

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
