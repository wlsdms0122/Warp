//
//  Executor.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

public struct Executor: Sendable {
    // MARK: - Property
    public let observer: (any ExecutionObserver)?
    public let environment: (any Environment)?

    // The linked call table, seeded from the image this run was given. Empty
    // until then, which is why nothing but `run(_ image:)` can start a run.
    let procedures: [String: Procedure]

    // What a path segment may reach, worked out by the link.
    let derivations: [String: Procedure]

    // The shapes the link declared. A named type is answered here rather than
    // expanded at link, so every boundary that settles arguments needs it.
    let types: TypeTable

    // MARK: - Initializer
    // Deliberately not public. An executor may only be made by the `Language`
    // that validated the procedure, so that the vocabulary which judged a procedure
    // is the vocabulary that runs it — a contract rather than a habit.
    init(
        observer: (any ExecutionObserver)?,
        environment: (any Environment)?,
        procedures: [String: Procedure] = [:],
        derivations: [String: Procedure] = [:],
        types: TypeTable = TypeTable()
    ) {
        self.observer = observer
        self.environment = environment
        self.procedures = procedures
        self.derivations = derivations
        self.types = types
    }

    // MARK: - Public
    // Running takes an image, not a procedure, so "ran something that was never
    // linked" is not a state this type can be put in.
    public func run(
        _ image: Image,
        arguments: [String: Value] = [:]
    ) async throws -> Value {
        try await Executor(
            observer: observer,
            environment: environment,
            procedures: image.procedures,
            derivations: image.derivations,
            types: image.types
        )
        .run(image.entry, arguments: arguments)
    }

    // MARK: - Private
    func run(
        _ procedure: Procedure,
        arguments: [String: Value] = [:],
        at trace: Trace = Trace()
    ) async throws -> Value {
        guard let block = procedure.block else {
            throw ExecutionError("a run starts from a body, and this declaration is native")
        }

        return try await answer(
            block,
            of: procedure.signature,
            in: Scope(bindings: try procedure.signature.settle(arguments, in: types)),
            at: trace
        )
    }

    // A body run as a procedure: what it answers is caught here, and what it
    // answers is settled against what it declared.
    //
    // Both halves are the frame, and neither works without the other — so there
    // is one of these rather than one per way of reaching a body. There are
    // three ways: a run starting here, a word whose implementation is written,
    // and a closure being invoked. When only the first caught a leaving, a
    // `return` inside a called body travelled out through its own frame and
    // became the *caller's* answer, settled against the caller's signature.
    private func answer(
        _ block: Block,
        of signature: Signature,
        in scope: Scope,
        at trace: Trace
    ) async throws -> Value {
        let returned: Value

        do {
            returned = try await run(block, in: scope, at: trace)
        } catch let leaving as Leaving where leaving.reach == .procedure {
            // A closure is a procedure, so this is also what stops a `return`
            // written inside one from answering for the procedure around it.
            returned = leaving.value
        }

        return try signature.settling(returned: returned, in: types)
    }

    // Statements bind in order. What comes back is the scope they built and what
    // the last one was worth — the second is for a caller that wants it, not
    // what the block answers with, which is `run(_ block:)`.
    func run(
        _ body: [Statement],
        in startScope: Scope,
        at trace: Trace
    ) async throws -> BlockResult {
        // The cancellation check sits at sequence entry, not only per statement —
        // an empty body inside a loop round must still observe cancellation, or
        // the caller's one lever against a runaway loop silently stops working.
        try Task.checkCancellation()

        var scope = startScope
        var lastResult = Value.null

        for (position, statement) in body.enumerated() {
            try Task.checkCancellation()

            let result = try await run(statement, at: position, in: scope, at: trace)

            switch (statement.binding, statement.id) {
            case let (.constant, id?):
                scope = scope.binding(id, to: result)

            case let (.variable, id?):
                scope = scope.declaring(id, as: result)

            // An assignment introduces nothing, so the scope is unchanged here
            // — the write went into a box the enclosing bodies also hold.
            case let (.assignment, id?):
                scope.assign(id, to: result)

            // A nameless statement ran for its effect, and the answer is
            // dropped — which is what leaving the name off said.
            case (_, nil):
                break
            }

            lastResult = result
        }

        return BlockResult(scope: scope, lastResult: lastResult)
    }

    // A body answers what it says it answers, and a body that says nothing
    // answers nothing.
    //
    // Reading the last statement instead would put a body's answer in its
    // ordering, where nothing points at it: appending a statement would change
    // what the body was worth, and the author who appended it wrote nothing that
    // says so. A loop and a walk already answered this way, so this is also the
    // language holding one rule where it held two.
    func run(_ block: Block, in scope: Scope, at trace: Trace) async throws -> Value {
        let outcome = try await run(block.body, in: scope, at: trace)

        guard let result = block.result else { return .null }

        return try await evaluate(result, in: outcome.scope, at: trace)
    }

    // The expression evaluator. `Resolver` answers the pure subset synchronously
    // — which is what an effect settling its operands needs — and everything
    // that runs a body or reaches outside is answered here, because both are
    // async and both can fail in ways a rescue may catch.
    func evaluate(
        _ expression: Expression,
        in scope: Scope,
        at trace: Trace
    ) async throws -> Value {
        switch expression {
        case .literal, .reference, .closure:
            return try resolver(in: scope).resolve(expression)

        // Nothing comes back, so this answers by not answering. What it carries
        // is worked out here, where the names it reads are still in scope.
        case let .leave(leave):
            var carried = Value.null

            if let value = leave.value {
                carried = try await evaluate(value, in: scope, at: trace)
            }

            throw Leaving(reach: leave.reach, target: leave.target, value: carried)

        case let .invoke(callee, arguments):
            return try await invoke(callee, arguments: arguments, in: scope, at: trace)

        case let .array(array):
            var values: [Value] = []

            for element in array {
                values.append(try await evaluate(element, in: scope, at: trace))
            }

            return .array(values)

        case let .record(record):
            var values: [String: Value] = [:]

            for (name, field) in record {
                values[name] = try await evaluate(field, in: scope, at: trace)
            }

            return .object(values)

        case let .block(block):
            return try await run(block, in: scope, at: trace)

        case let .conditional(condition, then, otherwise):
            let take = try resolver(in: scope).evaluate(condition)

            guard let taken = take ? then : otherwise else { return .null }

            return try await run(taken, in: scope, at: trace)

        case let .loop(condition, body, round):
            return try await loop(
                while: condition,
                body: body,
                round: round,
                in: scope,
                at: trace
            )

        case let .iteration(material, body, element):
            return try await iterate(
                over: material,
                body: body,
                element: element,
                in: scope,
                at: trace
            )

        case let .attempt(block, rescue, failure):
            return try await attempt(
                block,
                rescue: rescue,
                failure: failure,
                in: scope,
                at: trace
            )

        case let .dispatch(dispatch):
            return try await send(dispatch, in: scope, at: trace)

        }
    }

    // One lookup, because there is one table. A selector was resolved at link to
    // the name of a declaration, and what happens next is decided by how that
    // declaration is implemented — not by which container it was found in.
    func send(_ dispatch: Dispatch, in scope: Scope, at trace: Trace) async throws -> Value {
        let procedure = try resolve(dispatch.selector)

        switch procedure.implementation {
        // A query answers without running, so the pure resolver is the whole
        // implementation — it is here only so that `x.count` and the same
        // word written as a statement mean the same thing.
        case .query:
            return try Resolver(
                scope: scope,
                derivations: derivations.merging([dispatch.selector: procedure]) { _, new in new },
                types: types
            )
            .resolve(.dispatch(dispatch))

        case let .effect(effect):
            return try await effect.run(
                Invocation(
                    selector: dispatch.selector,
                    receiver: dispatch.receiver,
                    arguments: dispatch.arguments,
                    trace: trace,
                    scope: scope,
                    executor: self
                )
            )

        case let .body(block):
            let resolver = resolver(in: scope)
            // In name order, so the one order a program could observe — which
            // argument's refusal surfaces when two would refuse — is the
            // text's fact rather than a hash table's.
            var given: [String: Value] = [:]

            for (name, argument) in dispatch.arguments.sorted(by: { $0.key < $1.key }) {
                given[name] = try resolver.resolve(argument)
            }

            // A receiver is written on the other side of the dot rather than by
            // name. It is not settled as an argument — being sent to nothing is
            // something a word answers rather than refuses — but the body reads
            // it under the name its signature gave it.
            var declared = procedure.signature.parameters
            var received: (String, Value)?

            if let name = procedure.signature.receiver, let receiver = dispatch.receiver {
                declared[name] = nil
                received = (
                    name,
                    try procedure.signature.settling(
                        receiver: try resolver.resolve(receiver),
                        in: types
                    )
                )
            }

            var settled = try Signature(parameters: declared).settle(given, in: types)

            if let received { settled[received.0] = received.1 }

            return try await answer(
                block,
                of: procedure.signature,
                in: Scope(bindings: settled),
                at: trace.appending(.procedure(dispatch.selector))
            )
        }
    }

    // Calling a value. The body runs in the scope the closure captured and not
    // in the caller's — that is what lexical scope means, and it is the reason a
    // closure is worth passing at all.
    func invoke(
        _ callee: Expression,
        arguments: [String: Expression],
        in scope: Scope,
        at trace: Trace
    ) async throws -> Value {
        let resolver = resolver(in: scope)
        let value = try resolver.resolve(callee)

        guard case let .procedure(closure) = value else {
            throw ExecutionError(
                "this call names \(value.type), and only a procedure can be called"
            )
        }

        // Name order here too, for the same reason as a call's arguments.
        var resolved: [String: Value] = [:]

        for (name, argument) in arguments.sorted(by: { $0.key < $1.key }) {
            resolved[name] = try resolver.resolve(argument)
        }

        return try await answer(
            closure,
            settled: try closure.procedure.signature.settle(resolved, in: types),
            at: trace
        )
    }

    // Calling a closure a word holds. Arguments are offered rather than
    // settled strictly — the word decides what it has to give, and which of
    // those the closure's author wanted is the author's business.
    func call(
        _ closure: Closure,
        offering arguments: [String: Value],
        at trace: Trace
    ) async throws -> Value {
        try await answer(
            closure,
            settled: try closure.procedure.signature.settle(offered: arguments, in: types),
            at: trace
        )
    }

    // The one way a closure is entered, however its arguments were settled —
    // so whatever this boundary grows (observation, cancellation, how a return
    // lands) holds for a closure called as a value and one a word calls.
    private func answer(
        _ closure: Closure,
        settled: [String: Value],
        at trace: Trace
    ) async throws -> Value {
        guard let block = closure.procedure.block else {
            throw ExecutionError("a closure is a body, and this one is native")
        }

        var inner = closure.captured

        for (name, value) in settled {
            inner = inner.binding(name, to: value)
        }

        return try await answer(
            block,
            of: closure.procedure.signature,
            in: inner,
            at: trace
        )
    }

    func call(
        procedure name: String,
        arguments: [String: Value],
        in scope: Scope
    ) async throws -> Value {
        // procedure-to-procedure calls carry no termination guard — a name reappearing
        // in the call chain is not an oracle for a cycle (recursion over shrinking
        // input is legitimate), and a depth budget is policy, not mechanism.
        // Runaway calls are the caller's concern: observation and cancellation,
        // which propagate here through task cancellation.
        let procedure = try resolve(name)

        return try await run(procedure, arguments: arguments, at: Trace(frames: [.procedure(name)]))
    }

    // Linking put every name the document spells in this table, so there is
    // nowhere else for a name to be. A door for names the link never saw would
    // be a second way to call, and one that nothing checked — the promise this
    // language makes is that reaching a run means the reaching was settled.
    func resolve(_ name: String) throws -> Procedure {
        guard let linked = procedures[name] else {
            throw ExecutionError("procedure '\(name)' was not linked into this image")
        }

        return linked
    }

    // MARK: - Private
    private func resolver(in scope: Scope) -> Resolver {
        Resolver(scope: scope, derivations: derivations, types: types)
    }

    private func run(
        _ statement: Statement,
        at position: Int,
        in scope: Scope,
        at trace: Trace
    ) async throws -> Value {
        // The same notation the validator uses for a nameless statement, and
        // one an author's own name can never collide with — `_` is a name.
        let inside = trace.appending(.statement(statement.id ?? "[\(position)]"))

        await observer?.statementStarted(at: inside, expression: statement.expression)

        do {
            let result = try await evaluate(statement.expression, in: scope, at: inside)

            await observer?.statementCompleted(at: inside, result: result)

            return result
        } catch {
            let refused = refusal(error, at: inside)

            await observer?.statementFailed(at: inside, error: refused)

            throw refused
        }
    }

    // A refusal leaving a statement takes that statement's place with it, unless
    // it already carries one — the innermost is where the mistake is, and every
    // statement it passes through on the way out is only where the run was.
    private func refusal(_ error: any Error, at trace: Trace) -> any Error {
        guard let refused = error as? any WarpError, refused.trace == nil else { return error }

        return refused.tracing(trace)
    }

    private func loop(
        while condition: Expression,
        body: Block,
        round: String,
        in startScope: Scope,
        at trace: Trace
    ) async throws -> Value {
        var index = 0
        // What the last round that finished left behind. The result reads it,
        // because a result naming something the body bound is a thing the
        // checker allows and so a thing that has to work. A round that did not
        // finish contributed nothing, the same way a skipped round contributes
        // nothing to a walk.
        var settled = startScope

        while true {
            // A round is a block, so what it binds dies with it. Carrying the
            // round's whole scope into the next one would make every binding in
            // the body accidentally mutable to buy the one that had to be. A
            // variable declared outside the loop carries what the author meant
            // to carry, and nothing else comes with it.
            let state = Value.object(["index": .int(index)])
            let scope = startScope.binding(round, to: state)
            // Where the result is read: what the last finished round bound, plus
            // the round state as it stands now.
            let reading = settled.binding(round, to: state)

            let take = try resolver(in: scope).evaluate(condition)

            if !take {
                guard let result = body.result else { return .null }

                return try await evaluate(result, in: reading, at: trace)
            }

            do {
                settled = try await run(
                    body.body,
                    in: scope,
                    at: trace.appending(.round(index))
                )
                .scope
            } catch let leaving as Leaving where leaving.claimed(by: round) {
                guard leaving.reach == .round else {
                    // Ending the loop answers what ending it normally answers.
                    // A round that stopped early still bound what it bound, so
                    // the result reads the scope that round left behind — the
                    // same scope the checker showed it, and the same one a walk
                    // reads its result in.
                    guard let result = body.result else { return .null }

                    return try await evaluate(result, in: reading, at: trace)
                }
            }

            index += 1
        }
    }

    private func iterate(
        over material: Expression,
        body: [Statement],
        element: String,
        in startScope: Scope,
        at trace: Trace
    ) async throws -> Value {
        let elements = try await array(
            of: material,
            naming: element,
            in: startScope,
            at: trace
        )

        for (index, item) in elements.enumerated() {
            // Every round starts from the enclosing scope, the same rule the
            // loop states: carrying a round's scope into the next would make
            // every binding in the body accidentally live on. What a round
            // leaves behind is what it wrote to an outer variable — the box
            // carries that without any scope traveling.
            let scope = startScope.binding(
                element,
                to: .object(["item": item, "index": .int(index)])
            )

            do {
                _ = try await run(
                    body,
                    in: scope,
                    at: trace.appending(.round(index))
                )
            } catch let leaving as Leaving where leaving.claimed(by: element) {
                // A walk answers nothing, so ending one early ends it and no
                // more — what its rounds wrote outward is already written.
                guard leaving.reach == .round else { break }

                continue
            }
        }

        return .null
    }

    // The material both fan-out shapes walk. Whether the pieces run one after
    // another or all at once, what they walk has to be an array, and it fails to
    // be one in the same way.
    private func array(
        of material: Expression,
        naming element: String,
        in scope: Scope,
        at trace: Trace
    ) async throws -> [Value] {
        let resolved = try await evaluate(material, in: scope, at: trace)

        guard case let .array(elements) = resolved else {
            // A plain reference names its own locus; any other expression shape
            // has no path to point at, so the message carries the blame instead
            // of an empty `{ ref: }` rendering.
            guard let path = material.referencePath else {
                throw ExecutionError(
                    "the material of iteration '\(element)' resolved to"
                        + " \(resolved.type), expected array"
                )
            }

            throw ReferenceUnfit(
                path: path,
                reason: "iteration material is \(resolved.type), expected array"
            )
        }

        return elements
    }

    private func attempt(
        _ block: Block,
        rescue: Block,
        failure name: String,
        in scope: Scope,
        at trace: Trace
    ) async throws -> Value {
        do {
            return try await run(block, in: scope, at: trace)
        } catch {
            guard !Task.isCancelled else { throw error }

            // An author mistake passes through: a rescue is for what the world
            // did, not for what the procedure says.
            guard let recoverable = error as? any RecoverableFailure else { throw error }

            await observer?.failureRescued(name: name, error: error)

            // While the rescue runs, the failure is a value under the declared
            // name — readable, and gone the moment the rescue answers.
            return try await run(
                rescue,
                in: scope.binding(name, to: recoverable.payload),
                at: trace
            )
        }
    }
}
