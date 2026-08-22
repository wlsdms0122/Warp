//
//  Validator.swift
//  Warp
//
//  Created by JSilver on 8/8/26.
//

import Foundation

// Checks that every name a procedure reads is one it can see, before it runs.
//
// The walk is structural, and it stays structural through dispatch: a message
// carries expressions whose insides this can read, so what exists inside a
// caller's body is read here rather than asked of whatever answers the selector.
// Which means validation never consults the word table — a document is
// checked against itself, before anything is resolved.
public struct Validator: Sendable {
    // MARK: - Property
    // MARK: - Initializer
    public init() {
    }

    // MARK: - Public
    // The runtime lowering door must pass the same gate the load path does — a
    // body that arrived as data is validated against the heads visible where it
    // will run.
    public func validate(body: [Statement], visible: Set<String>) throws {
        try validate(body, visible: visible, label: "lowered")
    }

    // A single expression, checked where a caller is about to evaluate one it
    // assembled itself.
    public func validate(_ expression: Expression, visible: Set<String>) throws {
        try validate(expression, visible: visible, at: "expression")
    }

    // Every declaration a module makes, in name order so the first refusal is
    // stable across runs. Nothing about the module as a whole is checked here —
    // whether its names collide with another module's is a link question, and
    // there is no other module in sight from inside one.
    public func validate(_ module: Module) throws {
        let constants = Set(module.constants.keys)

        // A constant sees no scope, so it may name another constant and nothing
        // else. Which is also why it is checked here rather than per procedure:
        // what it can see is a fact about the module.
        for (name, expression) in module.constants.sorted(by: { $0.key < $1.key }) {
            try normal(name, at: "const.\(name)")
            try validate(expression, visible: constants, at: "const.\(name)")
        }

        for name in module.procedures.keys.sorted() {
            try normal(name, at: name)
        }

        for name in module.procedures.keys.sorted() {
            guard let procedure = module.procedures[name] else { continue }

            do {
                try validate(procedure, constants: constants)
            } catch let error as ValidationError {
                throw ValidationError("\(name): \(error.message)")
            }
        }
    }

    // A parameter is a name the body can read, so it is visible from the first
    // statement — and declared, so a statement cannot introduce it again. The
    // body and the signature are one scope, and a name is introduced once in a
    // scope.
    public func validate(_ procedure: Procedure, constants: Set<String> = []) throws {
        let parameters = Set(procedure.signature.parameters.keys)

        for parameter in parameters.sorted() {
            try normal(parameter, at: "parameters.\(parameter)")
        }
        let colliding = parameters.intersection(constants).sorted()

        guard colliding.isEmpty else {
            throw ValidationError(
                "parameters: \(colliding.joined(separator: ", ")) collides with a name"
                    + " the module bound, which it would take the place of"
            )
        }

        // A constant is declared, not merely visible: linking folds a reference
        // to one into the value it holds, so a statement that reintroduced the
        // name would leave two readings of the same spelling and only one of
        // them true.
        guard let block = procedure.block else { return }

        try validate(
            block,
            visible: constants.union(parameters),
            declared: parameters.union(constants),
            at: "body"
        )
    }

    // MARK: - Private
    @discardableResult
    private func validate(
        _ body: [Statement],
        visible startVisible: Set<String>,
        variables startVariables: Set<String> = [],
        declared startDeclared: Set<String> = [],
        surroundings: Surroundings = .procedure,
        label: String
    ) throws -> Set<String> {
        var visible = startVisible
        var variables = startVariables
        var declared = startDeclared

        for (position, statement) in body.enumerated() {
            // A binding with no name is a write that goes nowhere. The document
            // reader cannot produce one — the binding comes from the naming key
            // — so this guards the caller that builds statements directly.
            if statement.id == nil, statement.binding != .constant {
                throw ValidationError(
                    "\(label)[\(position)]: writes no name, and a \(statement.binding)"
                        + " is a statement about its name"
                )
            }

            if let id = statement.id {
                guard !id.isEmpty else {
                    throw ValidationError("\(label): statement with empty id")
                }

                try normal(id, at: "\(label).\(id)")

                // A leaving statement never finishes, so a name on one is a
                // binding that could never happen — refused rather than
                // remembered as false.
                if case .leave = statement.expression {
                    throw ValidationError(
                        "\(label).\(id): a leaving statement binds nothing,"
                            + " and it takes no name"
                    )
                }

                // A walk answers nothing, so a `var` or `set` on one is a write
                // whose value could only ever be null. The plain name stands
                // for the element inside the body, and that is all it is.
                if statement.binding != .constant, isIteration(statement.expression) {
                    throw ValidationError(
                        "\(label).\(id): a walk answers nothing, so its name"
                            + " binds the element and no value — it is not"
                            + " writable"
                    )
                }

                // An assignment is checked before the expression, because what
                // it may write is a fact about the name and not about the value.
                if case .assignment = statement.binding {
                    guard variables.contains(id) else {
                        // The most specific truth wins: a name that is visible
                        // but unwritable across a boundary is refused for the
                        // boundary, not for its binding.
                        let reason = if visible.contains(id), let boundary = surroundings.boundary {
                            boundary
                        } else if visible.contains(id) {
                            "which is a fixed name here — declare it as a variable to write it"
                        } else {
                            "which is not visible here — declare it earlier or check the spelling"
                        }

                        throw ValidationError(
                            "\(label): assigns '\(id)', \(reason)"
                        )
                    }
                }

                // Sub scopes restart declaration tracking, so an inner statement
                // may introduce a name an outer body also has — that is
                // shadowing, and it is a different name. Only same-level
                // duplicates are ambiguous.
                if case .assignment = statement.binding {} else {
                    guard !declared.contains(id) else {
                        throw ValidationError("\(label): duplicate statement id '\(id)'")
                    }

                    declared.insert(id)
                }
            }

            // Nothing runs after a statement that leaves, so a name written
            // after one would be read by something that never bound it.
            if case .leave = statement.expression, position != body.count - 1 {
                throw ValidationError(
                    "\(label)[\(position)]: nothing runs after leaving,"
                        + " and what follows it here would never bind"
                )
            }

            // The leave rules reach through structure, because the fact does: a
            // branch both of whose arms leave never finishes either, so a name
            // on such a statement could never bind and what follows it could
            // never run.
            if isLeaveThroughStructure(statement.expression) {
                if let id = statement.id {
                    throw ValidationError(
                        "\(label).\(id): every way through this statement"
                            + " leaves, so its name could never bind — it takes"
                            + " no name"
                    )
                }

                if position != body.count - 1 {
                    throw ValidationError(
                        "\(label)[\(position)]: every way through this"
                            + " statement leaves, and what follows it here"
                            + " would never run"
                    )
                }
            }

            try validate(
                statement.expression,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: "\(label).\(statement.id ?? "[\(position)]")"
            )

            switch (statement.binding, statement.id) {
            // A walk answers nothing, so its name is the element's — alive
            // inside the body as `item` and `index`, and nothing afterwards.
            // Leaving it visible would let what follows read a name whose only
            // value could ever be null, silently.
            case (.constant, _?) where isIteration(statement.expression):
                break

            case let (.constant, id?):
                visible.insert(id)
                variables.remove(id)

            case let (.variable, id?):
                visible.insert(id)
                variables.insert(id)

            default:
                break
            }
        }

        return visible
    }

    private func isIteration(_ expression: Expression) -> Bool {
        guard case .iteration = expression else { return false }

        return true
    }

    // Whether a *compound* statement leaves on every way through — the direct
    // leave has its own, more specific refusals above. Structural and
    // conservative: a loop may run no round and an attempt's rescue may finish
    // normally, so neither counts; a call is judged at the link, where its
    // signature is known.
    //
    // The link's type walk reads the same fact — a body ending never types
    // never, and joining two never arms answers never — over the full program,
    // symbols included. This is the symbol-free half of that judgment, and what
    // it buys is the stage: a document is refused before anything is linked.
    private func isLeaveThroughStructure(_ expression: Expression) -> Bool {
        switch expression {
        case let .conditional(_, then, otherwise):
            guard let otherwise else { return false }

            return alwaysLeaves(then) && alwaysLeaves(otherwise)

        case let .block(block):
            return alwaysLeaves(block)

        default:
            return false
        }
    }

    private func alwaysLeaves(_ block: Block) -> Bool {
        // A block answers through its result when it has one, so the judgment
        // follows the answer: a leaving result leaves the block, whatever the
        // body did. (A leaving *body* under a declared result is refused as
        // unreachable where the block itself is validated.)
        if let result = block.result {
            if case .leave = result { return true }

            return isLeaveThroughStructure(result)
        }

        return alwaysLeaves(block.body)
    }

    private func alwaysLeaves(_ body: [Statement]) -> Bool {
        guard let last = body.last else { return false }

        if case .leave = last.expression { return true }

        return isLeaveThroughStructure(last.expression)
    }

    private func validate(
        _ expression: Expression,
        visible: Set<String>,
        variables: Set<String> = [],
        surroundings: Surroundings = .procedure,
        at location: String
    ) throws {
        switch expression {
        case .literal:
            return

        case let .reference(path):
            try validate(paths: path.expandingIndexReferences, visible: visible, at: location)

        case let .array(array):
            for element in array {
                try validate(element, visible: visible, variables: variables, surroundings: surroundings, at: location)
            }

        case let .record(record):
            for (name, field) in record.sorted(by: { $0.key < $1.key }) {
                try validate(
                    field,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: "\(location).\(name)"
                )
            }

        // A closure sees where it was written plus what it declares, which is
        // the capture read statically. Its parameters are declared here for the
        // same reason a procedure's are: the signature and the body are one
        // scope.
        //
        // Variables are not carried in. A closure may outlive the block that
        // made it, so writing an enclosing box through one would be a write with
        // no bounded lifetime — a name it captured is a value it captured.
        // Where a leave may go. A closure is a procedure of its own, so the
        // loops around where it was *written* are not around where it runs —
        // `rounds` starts empty inside one, and reaching for an outer loop from
        // there is refused here rather than discovered at a run.
        case let .leave(leave):
            try validate(leave, in: surroundings, at: location)

        case let .closure(procedure):
            let parameters = Set(procedure.signature.parameters.keys)

            // The same rule the top-level signature gets — a closure's
            // parameter is a name a body reads, wherever the signature sits.
            for parameter in parameters.sorted() {
                try normal(parameter, at: "\(location).\(parameter)")
            }

            guard let block = procedure.block else { return }

            try validate(
                block,
                visible: visible.union(parameters),
                declared: parameters,
                surroundings: surroundings.enclosed,
                at: "\(location).closure"
            )

        case let .invoke(callee, arguments):
            try validate(callee, visible: visible, variables: variables, surroundings: surroundings, at: location)

            for (name, argument) in arguments.sorted(by: { $0.key < $1.key }) {
                try normal(name, at: "\(location).\(name)")
                try validate(
                    argument,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: "\(location).\(name)"
                )
            }

        case let .block(block):
            try validate(block, visible: visible, variables: variables, surroundings: surroundings, at: location)

        case let .conditional(condition, then, otherwise):
            try validate(
                condition,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: "\(location).when"
            )
            try validate(
                then,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: "\(location).then"
            )

            if let otherwise {
                try validate(
                    otherwise,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: "\(location).else"
                )
            }

        // The round state is bound before the condition is asked, which is what
        // lets `while` read how many rounds have passed.
        case let .loop(condition, body, round):
            try normal(round, at: "\(location).round")

            let inner = visible.union([round])

            try validate(
                condition,
                visible: inner,
                variables: variables,
                surroundings: surroundings,
                at: "\(location).while"
            )
            try validate(
                body,
                visible: inner,
                variables: variables,
                surroundings: surroundings.inside(round),
                at: location
            )

        case let .iteration(material, body, element):
            try normal(element, at: "\(location).element")

            try validate(
                material,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: "\(location).over"
            )
            try validate(
                body,
                visible: visible.union([element]),
                variables: variables,
                surroundings: surroundings.inside(element),
                label: location
            )

        // While the rescue runs, the failure is a value under the declared name.
        case let .attempt(block, rescue, failure):
            try normal(failure, at: "\(location).failure")

            try validate(
                block,
                visible: visible,
                variables: variables,
                surroundings: surroundings,
                at: location
            )

            guard !rescue.body.isEmpty || rescue.result != nil else {
                // An empty rescue would swallow a failure into null without a
                // trace — if the alternate path produces nothing, the author's
                // honest form is no rescue at all.
                throw ValidationError("\(location).rescue: must not be empty")
            }

            try validate(
                rescue,
                visible: visible.union([failure]),
                variables: variables,
                surroundings: surroundings,
                at: "\(location).rescue"
            )

        case let .dispatch(dispatch):
            if let receiver = dispatch.receiver {
                try validate(
                    receiver,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: location
                )
            }

            for (name, argument) in dispatch.arguments.sorted(by: { $0.key < $1.key }) {
                try normal(name, at: "\(location).\(name)")
                try validate(
                    argument,
                    visible: visible,
                    variables: variables,
                    surroundings: surroundings,
                    at: "\(location).\(name)"
                )
            }

        }
    }

    private func validate(
        _ block: Block,
        visible: Set<String>,
        variables: Set<String> = [],
        declared: Set<String> = [],
        surroundings: Surroundings = .procedure,
        at location: String
    ) throws {
        let inner = try validate(
            block.body,
            visible: visible,
            variables: variables,
            declared: declared,
            surroundings: surroundings,
            label: location
        )

        if let result = block.result {
            // The result runs after the body, so it is "after" the same way a
            // trailing statement is — a body that left never reaches it.
            if alwaysLeaves(block.body) {
                throw ValidationError(
                    "\(location).result: nothing runs after leaving,"
                        + " and this result would never be reached"
                )
            }

            try validate(
                result,
                visible: inner,
                variables: variables,
                surroundings: surroundings,
                at: "\(location).result"
            )
        }
    }

    // What a leave may say, and where it may say it.
    private func validate(
        _ leave: Leave,
        in surroundings: Surroundings,
        at location: String
    ) throws {
        guard leave.reach != .procedure else {
            guard leave.target == nil else {
                throw ValidationError(
                    "\(location): answering leaves the procedure it is written in,"
                        + " and names no other"
                )
            }

            return
        }

        guard leave.value == nil else {
            throw ValidationError(
                "\(location): a loop answers what it was going to answer,"
                    + " so ending one carries nothing"
            )
        }

        guard let nearest = surroundings.rounds.last else {
            throw ValidationError("\(location): there is no loop here to leave")
        }

        guard let target = leave.target else { return }

        try normal(target, at: location)

        guard surroundings.rounds.contains(target) else {
            throw ValidationError(
                "\(location): names '\(target)', which is not a loop around it"
                    + " — the ones here are \(surroundings.rounds.reversed().joined(separator: ", "));"
                    + " the nearest is '\(nearest)'"
            )
        }
    }

    private func validate(
        paths: [[PathSegment]],
        visible: Set<String>,
        at location: String
    ) throws {
        for path in paths {
            for segment in path {
                if case let .key(name) = segment {
                    try normal(name, at: location)
                }
            }

            guard let head = path.head else {
                throw ValidationError(
                    "\(location): reference { ref: \(path.rendered) } does not"
                        + " start with a name"
                )
            }

            guard visible.contains(head) else {
                throw ValidationError(
                    "\(location): reference { ref: \(path.rendered) } names"
                        + " '\(head)', which is not visible here — declare it earlier"
                        + " or check the spelling"
                )
            }
        }
    }

    // One name, one spelling. Record keys settled this at the encodings; a name
    // a document writes as a value — a statement's, a binding's, a reference's
    // — settles here, so a declaration and a reference can only meet by being
    // the same bytes. Compared as bytes on purpose: Swift's `==` would call two
    // spellings equal, which is the confusion being refused.
    private func normal(_ name: String, at location: String) throws {
        guard Name.isNormal(name) else {
            throw ValidationError(
                "\(location): the name '\(name)' is not in normal form C"
            )
        }
    }
}

// Where a body is, as far as leaving it is concerned.
//
// It is one value rather than a parameter each, because the parameters were
// individually forgettable and forgetting one was not an error — a body checked
// without its loops read as a body outside any loop, and a body checked without
// its boundary read as one whose outward writes were ordinary. Both of those
// were real: a `break` inside an `attempt` inside a loop was refused though it
// ran, and a closure's write to a captured name was nearly accepted.
//
// So the shape of this type is the point. Carrying it is the default, and every
// place that breaks it has to say so.
private struct Surroundings: Sendable {
    // MARK: - Property
    // The loops around here, nearest last. A name reaches past the nearer ones,
    // and nothing here means there is no loop to end.
    let rounds: [String]

    // Why a variable from outside cannot be written here, when it cannot — the
    // sentence the refusal says instead of "fixed name", which would be true
    // and useless. Nil where writing outward is ordinary.
    let boundary: String?

    // A procedure's own body: no loop yet, nothing fenced.
    static let procedure = Surroundings(rounds: [], boundary: nil)

    // MARK: - Public
    func inside(_ round: String) -> Surroundings {
        Surroundings(rounds: rounds + [round], boundary: boundary)
    }

    // A procedure written inside another. It may be called anywhere and long
    // after, so the loops around where it was written are not around where it
    // runs — and its own answer is its own.
    var enclosed: Surroundings {
        Surroundings(
            rounds: [],
            boundary: "which lives outside this closure — a closure captures"
                + " values, and a name it captured is a value it captured"
        )
    }

    // MARK: - Private
}
