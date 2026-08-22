//
//  TypeExpression+Binding.swift
//  Warp
//
//  Created by JSilver
//

import Foundation

// Working out what a call put in a declaration's holes, and reading the answer
// with those holes filled.
//
// This is the whole of what a type variable costs. Nothing infers across
// statements and nothing is solved: a call site is one place, what it hands over
// is already known there, and the holes are read off by walking the declaration
// beside what arrived.
public extension TypeExpression {
    // What the holes in this declaration stand for, given what arrived. Walked
    // in step: where the declaration has a hole, whatever sits opposite it is
    // what the hole stands for; where both have a shape, the walk goes inside.
    //
    // A hole reached twice has to be read the same both times. Two readings are
    // a disagreement rather than a reason to give up: widening to `any` was the
    // checker announcing it had stopped checking, and it announced it silently —
    // a list of strings handed an int to append read `Element` as `any` and the
    // call went through.
    //
    // Refusing instead is what one signature needs to say what several would
    // have said. `plus` declaring `some N` on both sides and answering `some N`
    // is a whole number added to a whole number answering a whole number, and a
    // whole number added to a fraction refused — without the language growing a
    // way to declare a name twice.
    func binding(
        against given: TypeExpression,
        into bound: inout [String: TypeExpression],
        disagreeing: inout [String: TypeExpression],
        in types: TypeTable = TypeTable()
    ) {
        switch (self, given) {
        case let (.variable(name), _):
            guard let already = bound[name] else {
                bound[name] = given

                return
            }

            guard already != given else { return }

            // Two readings agree when one takes the other — a list of numbers
            // and a whole number are not a disagreement, they are a hole read
            // once loosely and once tightly, and the loose reading is the one
            // that holds both.
            // `any` first, because it is the loosest reading there is and
            // `accepts` cannot order it: everything takes `any` and `any` takes
            // everything, so asking which is looser answers yes both ways and
            // whichever was read first would win. A hole read as `any` anywhere
            // is `any`, which is what a list of anything says about what may be
            // put in it.
            guard already != .any else { return }

            guard given != .any else {
                bound[name] = .any

                return
            }

            // With the table, because a reading may be a name a module
            // declared and the shape that name stands for. Asking without it
            // would call those two a disagreement, which is the same question
            // the link asks elsewhere and answers correctly.
            if already.accepts(given, in: types) { return }

            if given.accepts(already, in: types) {
                bound[name] = given

                return
            }

            // The first reading is kept so that what is reported names both,
            // and so that everything downstream sees one answer rather than a
            // hole that is two things.
            disagreeing[name] = given

        case let (.array(mine), .array(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, in: types)

        case let (.object(mine), .object(theirs)):
            mine.binding(against: theirs, into: &bound, disagreeing: &disagreeing, in: types)

        case let (.record(mine), .record(theirs)):
            for (name, field) in mine.sorted(by: { $0.key < $1.key }) {
                guard let opposite = theirs[name] else { continue }

                field.binding(against: opposite, into: &bound, disagreeing: &disagreeing, in: types)
            }

        case let (.procedure(.some(mine), _), .procedure(.some(theirs), _)):
            for (name, parameter) in mine.parameters.sorted(by: { $0.key < $1.key }) {
                guard let opposite = theirs.parameters[name] else { continue }

                parameter.declared.binding(against: opposite.declared, into: &bound, disagreeing: &disagreeing, in: types)
            }

            (mine.returns ?? .any).binding(against: theirs.returns ?? .any, into: &bound, disagreeing: &disagreeing, in: types)

        default:
            return
        }
    }

    // This type with every hole replaced by what it was read as. A hole nothing
    // filled reads `any`, which is what a declaration says when it says nothing.
    func filling(_ bound: [String: TypeExpression]) -> TypeExpression {
        switch self {
        case let .variable(name):
            return bound[name] ?? .any

        case let .array(element):
            return .array(element.filling(bound))

        case let .object(entry):
            return .object(entry.filling(bound))

        case let .record(fields):
            return .record(fields.mapValues { field in field.filling(bound) })

        case let .procedure(signature, purity):
            return .procedure(signature?.filling(bound), purity)

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .named:
            return self
        }
    }

    // Whether anything in here is a hole. A declaration without one is read the
    // way it always was, so nothing pays for a feature it does not use.
    var isGeneric: Bool {
        switch self {
        case .variable:
            return true

        case let .array(element), let .object(element):
            return element.isGeneric

        case let .record(fields):
            return fields.values.contains { field in field.isGeneric }

        case let .procedure(signature, _):
            return signature?.isGeneric ?? false

        case .any, .never, .null, .bool, .int, .double, .number, .string, .bytes, .named:
            return false
        }
    }
}

public extension Signature {
    func filling(_ bound: [String: TypeExpression]) -> Signature {
        Signature(
            receiver: receiver,
            parameters: parameters.mapValues { parameter in
                Parameter(
                    type: parameter.type?.filling(bound),
                    oneOf: parameter.oneOf,
                    default: parameter.default,
                    hint: parameter.hint
                )
            },
            returns: returns?.filling(bound)
        )
    }

    var isGeneric: Bool {
        parameters.values.contains { parameter in parameter.declared.isGeneric }
            || (returns?.isGeneric ?? false)
    }
}
