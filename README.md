# Warp

A language for programs that arrive after the program running them was built.

A compiled application cannot run code it did not ship with — no compiler at
run time, and on the platforms this exists for, no way to acquire one. Warp is
how a decision reaches a running program without rebuilding and re-shipping it:
the program arrives as a **document**, is **checked before any of it runs**,
and runs inside a runtime the receiver controls, reaching nothing the receiver
did not hand it.

## The pieces

```
what a person writes      YAML, a syntax of your own, …    front ends — many
        ↓
the document              one format, defined in spec/     ← what travels
        ↓  as bytes       binary · text                    encodings
        ↓
a runtime                 Swift today, others by spec       runtimes — many
```

A **front end** turns what a person wrote into a document and stops there. A
**runtime** reads documents, checks, links and runs them, and brings the host's
vocabulary. The two meet only at the document — a server can author with one,
two applications on two platforms can run with the other, and none of them
share code.

## This repository

| directory | what | is |
|---|---|---|
| [`spec/`](spec/README.md) | the language: shapes, document format, encodings, refusal rules, conformance cases | the specification |
| [`runtime/warp-runtime-swift/`](runtime/warp-runtime-swift/README.md) | `Warp` `WarpDocument` `WarpBinary` `WarpText` | one runtime |
| [`frontend/warp-frontend-yaml/`](frontend/warp-frontend-yaml/README.md) | `WarpYAML` | one front end |

The specification is the language. An implementation — this runtime included —
is complete when it does what the specification says, and no more complete for
doing anything else. A front end or runtime in another language starts from
`spec/README.md` and `spec/conformance/`, not from the Swift source.

## The shortest tour

Author with the front end, run with the runtime — the same two steps whether
the document crossed a network or a function call:

```swift
import WarpYAML          // authoring side
import WarpDocument      // arriving side
import Warp

let document = try YAMLFrontend().document(from: yaml)   // → canonical document
let module = try Loader().load(document)                  // checked, or refused
let image = try Language().link([module] + Module.standard, entry: "greet")
let answer = try await Language().makeExecutor().run(image)
```

A program that stays in Swift skips the document entirely and builds the
shapes directly; a program that travels goes as bytes — `WarpBinary` to carry,
`WarpText` to read.
