//
//  Linker+Typing.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// What each name in a body holds, worked out by reading the body in order.
//
// An author binds a call to a name and passes the name, so a declared `returns`
// only reaches the next call site if the link knows what that name holds. This
// is what knows: `said = call counts` followed by `wants(word: said)` is two
// declarations disagreeing, and both are text.
//
// It is inference and not a type system. Nothing here is required to say
// anything: what cannot be read is `any`, and `any` is accepted everywhere. A
// wrong answer would be a refusal an author cannot act on, so the walk answers
// only where the text says so.
extension Linker {
    // MARK: - Internal
    // The environment a procedure's body starts from: its own parameters, which
    // are the only names declared before the first statement.
    func environment(of signature: Signature) -> [String: TypeExpression] {
        signature.parameters.mapValues(\.declared)
    }

    // Every message in a block, each carrying what was in scope where it was
    // written. Statements are read in order because that is what a body means —
    // a name holds what the statement before it bound.
    func sites(
        in block: Block,
        at location: String,
        in environment: [String: TypeExpression],
        with frame: TypeFrame
    ) throws -> [Site] {
        let (sites, environment, reached) = try walk(
            block.body,
            at: location,
            in: environment,
            with: frame
        )

        guard let result = block.result else { return sites }

        guard reached else {
            throw LinkError(
                "\(location).result: never finishes before it, and nothing"
                    + " written after it would ever run"
            )
        }

        return sites + (try self.sites(in: result, at: location, in: environment, with: frame))
    }

    // A body with no result slot — the walk's, and any future one whose answer
    // is nothing by grammar.
    func sites(
        in body: [Statement],
        at location: String,
        in environment: [String: TypeExpression],
        with frame: TypeFrame
    ) throws -> [Site] {
        try walk(body, at: location, in: environment, with: frame).sites
    }

    private func walk(
        _ body: [Statement],
        at location: String,
        in environment: [String: TypeExpression],
        with frame: TypeFrame
    ) throws -> (sites: [Site], environment: [String: TypeExpression], reached: Bool) {
        var environment = environment
        var sites: [Site] = []

        // Whether this reading is still on a path the run would take. A
        // statement typed `never` ends the block right there — a fact one flag
        // holds, so the trailing statements and the result fall to the same
        // rule rather than to two.
        var reached = true

        for (position, statement) in body.enumerated() {
            guard reached else {
                throw LinkError(
                    "\(location)[\(position)]: never finishes, and nothing"
                        + " written after it would ever run"
                )
            }

            sites += try self.sites(
                in: statement.expression,
                at: "\(location).\(statement.id ?? "[\(position)]")",
                in: environment,
                with: frame
            )

            let written = type(of: statement.expression, in: environment, with: frame)

            // What the syntactic leaves get at reading, a call gets here, where
            // the signature is known: a statement typed `never` does not
            // finish, so a name on it promises a binding that cannot happen,
            // and nothing after it — statement or result — would ever run. The
            // rule is one rule — the reader catches the shapes it can see, and
            // the link catches the words only it can see.
            try refuseNeverBinding(written, named: statement.id, at: location)

            if written == .never { reached = false }

            // A write outlives the block it was written in, so a name written
            // anywhere inside this statement may hold something else by the time
            // the next one reads it. What that is depends on which way a branch
            // went, which no reading of the text decides — so it holds neither.
            for name in assigned(in: statement.expression) {
                environment[name] = .any
            }

            switch (statement.binding, statement.id) {
            case let (.constant, id?), let (.variable, id?):
                environment[id] = written

            case let (.assignment, id?):
                environment[id] = environment[id]
                    .map { held in held == written ? held : .any }
                    ?? written

            // A nameless statement writes no name for a later reading to find.
            case (_, nil):
                break
            }
        }

        return (sites, environment, reached)
    }

    // The one statement of the rule both walks share: what never finishes
    // binds nothing, so a name on it promises a binding that cannot happen.
    private func refuseNeverBinding(
        _ written: TypeExpression,
        named id: String?,
        at location: String
    ) throws {
        guard written == .never, let id else { return }

        throw LinkError(
            "\(location).\(id): never finishes,"
                + " so it binds nothing and takes no name"
        )
    }

    // What a call put in its callee's holes, read by walking each declared
    // parameter beside what was actually sent. A receiver is a parameter written
    // on the other side of the dot, so it is read the same way.
    func bound(
        of signature: Signature,
        at dispatch: Dispatch,
        in environment: [String: TypeExpression],
        with frame: TypeFrame
    ) -> Bound {
        var bound: [String: TypeExpression] = [:]
        var disagreeing: [String: TypeExpression] = [:]

        for (name, argument) in dispatch.arguments.sorted(by: { $0.key < $1.key }) {
            guard let parameter = signature.parameters[name] else { continue }

            parameter.declared.binding(
                against: type(of: argument, in: environment, with: frame),
                into: &bound,
                disagreeing: &disagreeing,
                in: frame.types
            )
        }

        guard
            let receiver = dispatch.receiver,
            let name = signature.receiver,
            let parameter = signature.parameters[name]
        else {
            return Bound(holes: bound, disagreeing: disagreeing)
        }

        parameter.declared.binding(
            against: type(of: receiver, in: environment, with: frame),
            into: &bound,
            disagreeing: &disagreeing,
            in: frame.types
        )

        return Bound(holes: bound, disagreeing: disagreeing)
    }

    // What an expression holds, as far as the text says. `any` wherever it does
    // not.
    func type(
        of expression: Expression,
        in environment: [String: TypeExpression],
        with frame: TypeFrame
    ) -> TypeExpression {
        switch expression {
        case let .literal(value):
            return type(of: value)

        // Nothing comes back from here, so there is no value to have a type.
        // `never` fits wherever it is written, which is what lets a branch whose
        // one arm leaves still be worth what the other arm is worth.
        case .leave:
            return .never

        case let .reference(path):
            return type(of: path, in: environment, with: frame)

        case let .array(array):
            return .array(
                array
                    .map { element in type(of: element, in: environment, with: frame) }
                    .reduce(nil) { joined, next in join(joined, next) } ?? .any
            )

        case let .record(record):
            return .record(
                record.mapValues { field in type(of: field, in: environment, with: frame) }
            )

        // A closure literal carries the signature it declared, so handing one to
        // a slot that declared what it wants is two declarations meeting. Its
        // purity is read the same way a declaration's is — from what the body
        // calls — which is why a slot may ask for it and this can answer.
        case let .closure(procedure):
            let body = procedure.block
                .map { block in isPure(resolved: block, given: frame.pure) } ?? false

            return .procedure(procedure.signature, body ? .pure : .unstated)

        // A call answers what its callee declared, which is the fact this whole
        // walk exists to carry. A declaration with a hole in it answers nothing
        // until this call fills
        // it, so the holes are read from what was actually sent and the answer
        // comes back with them filled.
        case let .dispatch(dispatch):
            guard let signature = frame.signatures[dispatch.selector] else { return .any }
            guard let returns = signature.returns else { return .any }
            guard signature.isGeneric else { return returns }

            return returns.filling(
                bound(of: signature, at: dispatch, in: environment, with: frame).holes
            )

        // Which value is called is settled at run time, so nothing here can say
        // what it answers.
        case .invoke:
            return .any

        case let .block(block):
            return type(of: block, in: environment, with: frame)

        // A condition that declines answers null, so a branch with no other arm
        // has two readings like any other — its body, and the null it answers
        // when it is not taken.
        case let .conditional(_, then, otherwise):
            guard let otherwise else {
                return join(type(of: then, in: environment, with: frame), .null)
            }

            return join(
                type(of: then, in: environment, with: frame),
                type(of: otherwise, in: environment, with: frame)
            )

        // A loop answers its body's declared result, and null when it has none.
        case let .loop(_, body, round):
            guard body.result != nil else { return .null }

            return type(
                of: body,
                in: environment.merging([round: Self.roundType]) { _, new in new },
                with: frame
            )

        // A walk answers nothing — a walk that answered would be a map.
        case .iteration:
            return .null

        case let .attempt(block, rescue, _):
            return join(
                type(of: block, in: environment, with: frame),
                type(of: rescue, in: environment, with: frame)
            )

        }
    }

    // Walking a path through types the way the resolver walks it through values:
    // a segment names a field, an element, or a word sent to what the walk has
    // reached.
    //
    // Where the walk read a shape and the shape has room for none of those, the
    // run would refuse, so this refuses instead — the whole point of deciding
    // before running. Where it read nothing it says so and stops looking, which
    // is why an unread head is not a mistake.
    func reach(
        of path: [PathSegment],
        in environment: [String: TypeExpression],
        with frame: TypeFrame
    ) -> Reach {
        guard case let .key(head)? = path.first, var current = environment[head] else {
            return .reads(.any)
        }

        var walked: [PathSegment] = [.key(head)]

        for segment in path.dropFirst() {
            current = frame.resolve(current)
            walked.append(segment)

            switch (segment, current) {
            // Nothing is known about what an unread shape holds, and drilling
            // into null is absence rather than misuse. Neither is something an
            // author could act on, so neither is said.
            case (_, .any):
                return .reads(.any)

            case (_, .null):
                return .reads(.null)

            // An index written as a reference is a name the run settles, so
            // where it lands is not readable here.
            case (.indexRef, _):
                return .reads(.any)

            case (.index, .array(let element)):
                current = element

            case (.key(let key), .record(let fields)):
                current = fields[key] ?? frame.returns(of: key) ?? .any

            case (.key, .object(let entry)):
                current = entry

            // A segment that names no field of a shape this walk can read is a
            // word. A shape that holds no fields at all leaves nothing else it
            // could be, so a name no word answers is a name nothing answers.
            case (.key(let key), _):
                guard let answered = frame.returns(of: key) else {
                    return .refused(
                        "\(walked.rendered) sends '\(key)' to \(current.rendered),"
                            + " which has no such field and which no word by that"
                            + " name is declared for"
                    )
                }

                current = answered

            case (.index, _):
                return .refused(
                    "\(walked.rendered) indexes into \(current.rendered),"
                        + " and only an array is indexed"
                )
            }
        }

        return .reads(current)
    }

    // MARK: - Private
    private static let roundType = TypeExpression.record(["index": .int])

    // Every name written anywhere inside an expression, however deep. Writing is
    // the one thing a nested body does that the body around it has to know
    // about, because a write is to a box the enclosing body holds.
    private func assigned(in expression: Expression) -> Set<String> {
        switch expression {
        case .literal, .reference, .closure, .invoke:
            return []

        case let .leave(leave):
            return leave.value.map(assigned(in:)) ?? []

        case let .array(array):
            return array.reduce(into: Set()) { names, element in
                names.formUnion(assigned(in: element))
            }

        case let .record(record):
            return record.values.reduce(into: Set()) { names, field in
                names.formUnion(assigned(in: field))
            }

        case let .block(block):
            return assigned(in: block)

        case let .conditional(condition, then, otherwise):
            return assigned(in: condition)
                .union(assigned(in: then))
                .union(otherwise.map(assigned(in:)) ?? [])

        case let .loop(condition, body, _):
            return assigned(in: condition).union(assigned(in: body))

        case let .iteration(material, body, _):
            return assigned(in: material).union(assigned(in: body))

        case let .attempt(block, rescue, _):
            return assigned(in: block).union(assigned(in: rescue))

        case let .dispatch(dispatch):
            return dispatch.arguments.values
                .reduce(into: dispatch.receiver.map(assigned(in:)) ?? []) { names, argument in
                    names.formUnion(assigned(in: argument))
                }

        }
    }

    private func assigned(in block: Block) -> Set<String> {
        assigned(in: block.body).union(block.result.map(assigned(in:)) ?? [])
    }

    private func assigned(in body: [Statement]) -> Set<String> {
        body.reduce(into: []) { names, statement in
            names.formUnion(assigned(in: statement))
        }
    }

    private func assigned(in statement: Statement) -> Set<String> {
        var names = assigned(in: statement.expression)

        if case .assignment = statement.binding, let id = statement.id { names.insert(id) }

        return names
    }

    private func sites(
        in expression: Expression,
        at location: String,
        in environment: [String: TypeExpression],
        with frame: TypeFrame
    ) throws -> [Site] {
        func inner(_ expression: Expression) throws -> [Site] {
            try sites(in: expression, at: location, in: environment, with: frame)
        }

        func inner(_ block: Block) throws -> [Site] {
            try sites(in: block, at: location, in: environment, with: frame)
        }

        switch expression {
        case .literal:
            return []

        case let .leave(leave):
            return try leave.value.map(inner) ?? []

        // A path names something that has to exist just as a selector does, so
        // it is gathered rather than passed over.
        case let .reference(path):
            return [
                .reach(ReachSite(path: path, location: location, environment: environment))
            ]

        case let .array(array):
            return try array.flatMap(inner)

        case let .record(record):
            return try record.values.flatMap(inner)

        // A closure's body is followed even though nothing here can say whether
        // it is ever called — the warrant is compilation, and a body that never
        // runs still has to compile. It sees what surrounds it plus what it
        // declares.
        case let .closure(procedure):
            guard let block = procedure.block else { return [] }

            return try sites(
                in: block,
                at: "\(location).closure",
                in: environment.merging(self.environment(of: procedure.signature)) {
                    _, new in new
                },
                with: frame
            )

        case let .invoke(callee, arguments):
            return try inner(callee) + arguments.values.flatMap(inner)

        case let .block(block):
            return try inner(block)

        // Unreached arms are followed on purpose.
        case let .conditional(condition, then, otherwise):
            return try inner(condition) + inner(then) + (otherwise.map(inner) ?? [])

        case let .loop(condition, body, round):
            let inside = environment.merging([round: Self.roundType]) { _, new in new }

            return try sites(in: condition, at: location, in: inside, with: frame)
                + sites(in: body, at: location, in: inside, with: frame)

        case let .iteration(material, body, element):
            let item: TypeExpression

            if case let .array(held) = type(of: material, in: environment, with: frame) {
                item = held
            } else {
                item = .any
            }

            return try inner(material)
                + sites(
                    in: body,
                    at: location,
                    in: environment.merging(
                        [element: .record(["item": item, "index": .int])]
                    ) { _, new in new },
                    with: frame
                )

        case let .attempt(block, rescue, failure):
            return try inner(block)
                + sites(
                    in: rescue,
                    at: "\(location).rescue",
                    in: environment.merging([failure: .any]) { _, new in new },
                    with: frame
                )

        case let .dispatch(dispatch):
            return [
                .call(CallSite(dispatch: dispatch, location: location, environment: environment))
            ]
                + (try dispatch.receiver.map(inner) ?? [])
                + (try dispatch.arguments.values.flatMap(inner))

        }
    }

    private func type(of block: Block, in environment: [String: TypeExpression], with frame: TypeFrame) -> TypeExpression {
        var environment = environment
        var last = TypeExpression.null

        for statement in block.body {
            last = type(of: statement.expression, in: environment, with: frame)

            // A statement the body does not come back from ends the reading.
            // What is written after it is not reached, so it says nothing about
            // what the block answers — and neither does a result it never gets
            // to evaluate.
            guard last != .never else { return .never }

            if let id = statement.id {
                environment[id] = last
            }
        }

        // What a body with no result answers, which is nothing — the same rule
        // the run follows. Reading the last statement's type here while the run
        // answers null would let a procedure declaring `int` and naming no
        // result link and then fail every time it ran.
        guard let result = block.result else { return .null }

        return type(of: result, in: environment, with: frame)
    }

    private func type(
        of path: [PathSegment],
        in environment: [String: TypeExpression],
        with frame: TypeFrame
    ) -> TypeExpression {
        guard case let .reads(read) = reach(of: path, in: environment, with: frame) else {
            return .any
        }

        return read
    }

    private func type(of value: Value) -> TypeExpression {
        switch value {
        case .null:
            return .null

        case .bool:
            return .bool

        case .int:
            return .int

        case .double:
            return .double

        case .string:
            return .string

        case .bytes:
            return .bytes

        // A procedure that already exists as a value says nothing about itself
        // that this walk can read.
        case .procedure:
            return .procedure(nil, .unstated)

        case let .array(elements):
            return .array(
                elements
                    .map(type(of:))
                    .reduce(nil) { joined, next in join(joined, next) } ?? .any
            )

        case let .object(fields):
            return .record(fields.mapValues(type(of:)))
        }
    }

    // Two readings of one slot. Where they disagree the slot holds neither,
    // which is what `any` says — a join that guessed would be a refusal an
    // author cannot act on.
    //
    // A reading that leaves is not one of the two. It contributes no value, so
    // it cannot disagree with the reading that stays, and the slot holds what
    // the other one said.
    private func join(_ left: TypeExpression?, _ right: TypeExpression) -> TypeExpression {
        guard let left else { return right }
        guard left != .never else { return right }
        guard right != .never else { return left }

        // Two procedures join to a procedure rather than to `any`, keeping the
        // purity both of them have. Collapsing here would let one impure body in
        // a list of them pass a slot that asked for none, because `any` is
        // accepted everywhere.
        if
            case let .procedure(mine, wanted) = left,
            case let .procedure(theirs, offered) = right
        {
            return .procedure(
                mine == theirs ? mine : nil,
                wanted == .pure && offered == .pure ? .pure : .unstated
            )
        }

        return left == right ? left : .any
    }
}
