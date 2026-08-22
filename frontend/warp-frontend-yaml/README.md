# warp-frontend-yaml

The YAML front end for [Warp](../../spec/README.md). What a person writes in
YAML becomes a **canonical document** — the one format that travels — and that
is the whole job: a front end ends where the document begins, and nothing
runnable ever comes out of one.

```swift
import WarpYAML

let document = try YAMLFrontend().document(from: yaml)
```

The output is a validated, spelled-out document: every shorthand this notation
offers has been spent, the manifest (`warp`, `needs`) has been computed, and a
program the language would refuse is refused here, at the author's desk, rather
than where it arrives. Feed it to any runtime's loader — the same call a
program arriving over the network comes through:

```swift
import Warp
import WarpDocument      // the Swift runtime's reading side

let module = try Loader().load(document)
```

## The notation

```yaml
name: greeter

const:
  greeting: hello

types:
  Task:
    id: string
    done: bool

procedures:
  greet:
    parameters:
      names: array<string>
    returns: string
    body:
      - id: many
        value: { ref: names.count }
      - id: gate
        branch:
          when: { of: { ref: many }, greaterThan: 0 }
          then:
            body:
              - id: line
                value: { format: "${g}, ${who}", with: { g: { ref: greeting }, who: { ref: names.first } } }
            result: { ref: line }
          else:
            body:
              - id: empty
                value: nobody
            result: { ref: empty }
    result: { ref: gate }
```

The structure is the document format defined in the specification. What this
notation adds on top is **spellings** — shorthands that stand in for shapes the
language already has:

- **Condition operators** in `when`/`where` slots: `is`, `is_not`, `not`,
  `all_of`, `any_of`, `one_of`, `present`, and a bare word like `greaterThan`
  as an operator. Each is a message written shorter — `{ of: x, is: 3 }` is
  `equal` sent to `x`.
- **Templates**: `{ format: "${g}, ${who}", with: … }` is the words that put
  text together, written as the text they put together. Closed — a template
  sees its declared bindings and nothing from the ambient scope.

A spelling is spent before the document leaves; what leaves writes the shapes
themselves, so a runtime never has to know this notation existed. That is also
why YAML scalars behave literally here — a string is never re-parsed into
anything live.

## A construct word of your own

A host that authors its own constructs registers a form and reads with it:

```swift
import Warp
import WarpDocument
import WarpYAML

struct UnlessForm: ConstructForm {
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case when
        case body
        case result
    }

    static let key = "unless"

    private let condition: Warp.Expression
    private let block: Block

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.condition = try container.decode(ConditionReader.self, forKey: .when).condition
        self.block = Block(
            body: try container.decodeIfPresent([StatementReader].self, forKey: .body)?
                .map(\.statement) ?? [],
            result: try container.decodeIfPresent(ExpressionReader.self, forKey: .result)?
                .expression
        )
    }

    func expression(boundTo id: String) -> Warp.Expression {
        .conditional(
            .dispatch(Dispatch(receiver: condition, selector: "not")),
            then: block,
            else: nil
        )
    }
}

let loader = Loader(
    registry: try ConstructRegistry.standard.registering(UnlessForm.self),
    spellings: .standard
)
let module = try loader.load(try YAMLParser().parse(yaml))
```

A registered form is this host's own notation. A document written with it does
not travel — which is the trade being made, and why it is made explicitly.

## Fragments

A host that lowers statements mid-run has no document; it parses and reads,
which are the two pieces this package and the runtime already are:

```swift
let statements = try Loader(spellings: .standard)
    .statements(from: try YAMLParser().parse(fragment))
```

## What this package depends on

`YAMLParser` is text in, `Value` out, and knows nothing about programs. The
lowering currently *borrows* the runtime's spelled reader (`WarpDocument`) and
hands the canonical writer the result — so this package depends on
`warp-runtime-swift` today. The boundary is already the document; a front end
that lowers its own spellings against the specification alone is the step that
removes the dependency.
