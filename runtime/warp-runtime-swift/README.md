# warp-runtime-swift

The Swift runtime for [Warp](../../spec/README.md). It reads documents, checks
and links them before anything runs, runs them under a caller that can always
stop them, and brings the host's vocabulary. What the language *is* lives in
the specification; this package is one implementation of it.

A program can also be built directly as Swift values — `Module`, `Procedure`,
`Statement`, `Expression` — and never touch a document. That is not a trick:
it is what a program that stays where it was built looks like.

```swift
import Warp

let language = Language()

let greet = Procedure(
    signature: Signature(
        parameters: ["name": Parameter(type: .string)],
        returns: .string
    ),
    body: [
        Statement(
            id: "greeting",
            expression: .dispatch(
                Dispatch(
                    receiver: .array([
                        .literal(.string("hello, ")),
                        .dispatch(
                            Dispatch(receiver: .reference([.key("name")]), selector: "text")
                        )
                    ]),
                    selector: "joined"
                )
            )
        )
    ],
    result: .reference([.key("greeting")])
)

let image = try language.link(
    [Module(name: "hello", procedures: ["greet": greet])] + Module.standard,
    entry: "greet"
)

let value = try await language.makeExecutor().run(
    image,
    arguments: ["name": .string("warp")]
)

// value == .string("hello, warp")
```

## The products

| product | what | depends on |
|---|---|---|
| `Warp` | the shapes, checking, linking, running, and the standard vocabulary | nothing |
| `WarpDocument` | a document read into shapes, and shapes written back out | `Warp` |
| `WarpBinary` | the carrying encoding — Warp's own bytes | `Warp` |
| `WarpText` | the readable encoding — the same document laid out for eyes | `Warp` |

The arrows are the architecture. An encoding carries a tree of data and never
learns what the tree means, so both see `Warp`'s `Value` and nothing of
`WarpDocument`. `WarpDocument` is optional in the honest sense: a program that
never travels never links it.

## An arriving program

```swift
import Warp
import WarpDocument
import WarpBinary

let document = try BinaryEncoding.value(from: bytes)   // bytes → tree, or refused
let module = try Loader().load(document)               // tree → module, or refused
let image = try Language().link([module] + Module.standard, entry: "entry")
let answer = try await Language().makeExecutor().run(image)
```

Each step refuses rather than guesses, and everything refusable is refused
while nothing has run — including the branches this run would not have taken.
The stages and what each one checks are the specification's, not this file's.

`Loader` reads the canonical document and nothing else by default. Which
construct words exist is a `ConstructRegistry`; a host may register its own
forms, and a notation layer (a front end) may hand a `SpellingRegistry` to
read spelled documents — the wire never carries a spelling.

`Writer` is the way back out: a program that was *built* rather than read has
no document to hand to anything running elsewhere, and this is how it gets one.

## Vocabulary — the boundary to the outside

A word is a procedure whose implementation is native. `Query` answers without
running; `Effect` answers by running. Everything a program can do to the world
goes through a word the host declared, which is what makes the host's
vocabulary the bounds of an arriving program.

```swift
struct ShoutQuery: Query {
    func evaluate(_ question: Question) throws -> Value? {
        guard case let .string(text) = question.receiver else { return nil }

        return .string(text.uppercased())
    }
}

let vocabulary = Module(
    name: "app",
    procedures: [
        "shout": Procedure(
            signature: Signature(
                receiver: "of",
                parameters: ["of": Parameter(type: .string)],
                returns: .string
            ),
            implementation: .query(ShoutQuery())
        )
    ]
)
```

Link it beside `Module.standard` and a document may write `name.shout` — and a
document that sends a word nobody linked is refused by name before anything
runs. The standard vocabulary ships the same way: bundles a caller takes what
it wants from, no second namespace and no second lookup order.

## Stopping and watching

A run can always be stopped from outside — cancellation is observed between
statements and at the entry of every round. Nothing is bounded from inside: no
fan-out cap, no recursion depth, no iteration limit a program did not write
itself (`loop`'s `guard` is the author bounding their own program). Runaway
work is watched through `ExecutionObserver` and stopped by cancelling the
task, which is the one promise the language makes about consumption.

## Conformance

`WarpConformanceTests` runs the cases in [`spec/conformance/`](../../spec/conformance)
through public API only. A runner that could see inside could pass by agreeing
with the implementation rather than with the specification, which is the one
thing it must not do.

## Status

Settled enough to write in, not settled enough to be stable. Everything above
is implemented and tested — the examples on this page are executed by test
suites rather than transcribed into them. Names still move; a program written
against this package should expect to be edited when they do.
