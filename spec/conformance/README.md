# Conformance

The rules in `../README.md`, as cases that run.

Prose ages against an implementation that keeps moving, and an implementation is
the last thing that should be asked whether it is correct. These are the
questions asked instead — data rather than code, so an implementation written in
another language runs the same cases and finds out the same things.

## What a case is

One file, one question. A document, what to run it with, and what should happen.

    name        what the case is called
    note        why it exists — the rule it holds an implementation to
    program     a document
    arguments   what the entry procedure is given, if anything
    expect      answers: <value>     it runs and answers this
                refuses: <stage>     it is refused, at load, link or run

Both kinds matter equally. **An implementation that accepts a program another
refuses has failed in the same way as one that answers differently**, so half of
these say what must *not* run, and where it must stop.

The stage is part of the answer. Refusing at run what another implementation
refuses at link means something already happened before the refusal — and what
already happened cannot be taken back, which is most of why this language checks
before it runs.

## What a runner does

Read the file. Read `program` as a document. If `expect` says `refuses`, check
that it fails at that stage and no earlier or later. Otherwise link it against
the standard vocabulary, run it with `arguments`, and compare.

Nothing here reaches inside an implementation. A runner uses what any caller
would use, which is what makes passing these mean something.

## How a case is written

Nobody composes canonical text by hand — that stays true here. A case is
authored as any document is (a front end, a literal in a host language) and
**dumped** through a canonical writer into the `.warpt` that lands in this
directory. The dump is the artifact; the authoring form is scaffolding and is
not kept. An implementation adding cases writes its own dumper anyway — it is
the same writer conformance already requires of it.
