# The Warp specification

Warp is a language, and this is where the language is. The directories beside
this one hold implementations of it; nothing they do adds to the language, and
the work of these pages is to owe them nothing — the last section says where
that is still not true.

This describes **Warp 0.1.0**. Nothing has shipped: no document exists anywhere
this specification does not control, and the numbers below start moving at the
first release.

This document is written the way a protocol is written: it says what a
conforming implementation **must** do, field by field and byte by byte, and the
cases under `conformance/` are the same statements as data. An implementation is
a thing you can be *wrong at*.

## What Warp is

A language for programs that arrive after the program running them was built.

A compiled application cannot run code it did not ship with. Handed a source
file at run time it has no compiler, and on the platforms this exists for it may
not acquire one — so the only way a decision reaches a running program without
rebuilding and re-shipping it is for something inside to read that decision and
carry it out. Warp is what that something reads.

Everything else follows from *arrive*:

- **The program comes from elsewhere**, so the receiving side cannot assume it
  was checked. Checking is the receiver's job, not a favour the sender did.
- **The program crosses machines as bytes**, so there is a document format, and
  the two ends have to agree about what the bytes say.
- **The sender and the receiver may be different implementations** — a server in
  one language, two applications in two others — so agreement cannot mean "the
  same code".
- **The program is not trusted**, so what it can do is bounded by something the
  receiver controls.

## The pieces

```
what a person writes        YAML, a syntax of your own, …   front ends — many, replaceable
        ↓
the document                one format, this specification  ← what travels
        ↓  as bytes         binary / text                   encodings of the document
        ↓
the shapes                  this specification              what a program is made of
        ↓
a runtime                   Swift, Kotlin, …                implementations — many, replaceable
```

- A **front end** turns what a person wrote into a document. Its input syntax
  and its shorthands are its own; its output is this specification's. A front
  end owes nothing to any runtime and never produces anything runnable.
- The **document** is a program written down: a tree of data whose keys and
  slots this specification fixes. It is the only thing that crosses machines.
- An **encoding** is bytes for that tree. Two are specified below; a document
  is the same document in either of them.
- A **runtime** reads documents, checks, links and runs them, and brings the
  host's vocabulary. How it holds a program in memory is its own business.

## Conformance language

**must / must not** are requirements. **refuses** means the implementation
raises an error naming what was wrong and produces nothing else — no partial
value, no best guess, no reading what it recognised and skipping the rest.

Refusals happen at one of three stages, and the stage is part of the behaviour:

1. **Reading** — the bytes or the tree are not a document.
2. **Checking and linking** — the document is a document, and the program it
   writes is not sound: a name resolves nowhere, a call does not fit the
   declaration it reaches, a word no module provides. Nothing has run yet.
3. **Running** — the program was sound and the world disagreed: division by
   zero, overflow, a failure a word raised.

Two implementations that run the same programs identically and disagree about
which programs to refuse — or *where* — are not the same language. A refusal at
the run where another implementation refuses at the link means something already
happened, and what already happened cannot be taken back.

The cases under `conformance/` name the stages **`load`**, **`link`** and
**`run`**. `load` is reading plus the half of the checking a document answers
alone — a document is checked as it is loaded, and to a caller the two are one
refusal surface; `link` is the half that needs the rest of the link — words,
declared type names, signatures; `run` is running. So a `ref` that resolves
nowhere in its own document refuses at `load`, and a word no module declares
refuses at `link`.

## The value model

A program computes over eight kinds of data, plus one value that is not data:

| kind | writes as | notes |
|---|---|---|
| null | `null` | |
| bool | `true` / `false` | |
| int | `1`, `-3` | signed, 64-bit; overflow **refuses**, it does not wrap |
| double | `1.0`, `1e2` | IEEE-754 binary64; a document cannot carry infinity or NaN |
| string | `"hi"` | Unicode text |
| bytes | `x"6869"` | raw bytes; what a carrying form carries when the payload is not text |
| array | `[ … ]` | ordered |
| record | `{ … }` | unordered fields, names unique |
| procedure | — | code with what it captured; exists only at run time, never in a document |

**When two values are the same:**

- A whole number and a fraction of the same size are the same value. Numbers
  are compared by what they are worth, not by which of the two they are.
- A fraction that is not a number is not equal to itself. There is one such
  value, no way to write it down, and the standard vocabulary never answers
  one — arithmetic with no finite answer refuses instead — so it arises only
  from a host's own word.
- Bytes are the same when their bytes are, in order. Bytes are not text: no
  encoding is assumed, so no Unicode rule applies.
- Arrays are the same when their elements are, in order.
- Records are the same when they hold the same names bound to the same values.
  A record has no order, so order is not part of the answer.
- Null is the same as null.
- **Text is counted and compared as a person reads it**: by extended grapheme
  cluster, under Unicode canonical equivalence. A letter written as a letter
  and the same letter written as letter-plus-combining-mark are one character
  and are equal; `"é"` is `"é"` whichever way its bytes spell it, and its
  `count` is 1. An implementation whose platform strings compare by code unit
  must not expose that comparison here.

## Types

A type is written as a string, or as a record for the two shapes a string
cannot say:

| written | means |
|---|---|
| `null` `bool` `int` `double` `string` `bytes` | the scalar kinds |
| `number` | whole or fraction — the two numeric kinds and nothing else |
| `any` | anything |
| `never` | never answers — the type `std.control.abort` declares, and what makes a leaving call checkable |
| `array` / `object` | a list / map of anything |
| `array<T>` / `object<T>` | a list / map of `T` |
| `procedure` | some procedure, signature unsaid |
| `pure <procedure type>` | a procedure that answers without running effects |
| `Task` (any declared name) | the type a module declares under that name |
| `some T` | a hole: worked out from the call, same reading everywhere it appears |
| `{ id: string, done: bool }` | a record type, written as the record it describes |
| `{ procedure: { parameters: …, returns: … } }` | a procedure type, written as the signature it takes |

Acceptance is one-way where the kinds nest: `double` accepts an `int` (a whole
number widens to a fraction; the reverse **refuses**), `number` accepts both and
nothing else, `any` accepts everything.

`never` is a real type and fits **every** slot, by never arriving: an
expression typed `never` may be written where any value is expected — a branch
arm that leaves, an argument that aborts — and evaluating it ends the
evaluation it is inside. The statement rules (no name, nothing follows) are
statement rules; in expression position there is nothing extra to say, because
nothing after the expression is reached at all.

**Holes.** A declaration may leave a hole and let the call fill it: a word
taking `array<some T>` and a `some T` answers what it was given. A hole read
twice must be read the same both ways. Two readings where one accepts the other
settle on the looser; two readings that do not fit are **refused** — appending a
whole number to a list of text is a hole read as text and as a number, and
there is no answer that is both. It must be a refusal rather than a silent
widening to `any`: widening there is the checking announcing it has stopped, in
the one place it had just found what it was looking for.

## The document format

A document is one record. Every record below is **closed**: a key not named
here **refuses**. Every slot marked *expression*, *block*, *statements* or
*type* takes the grammar of that name.

### The module

| key | takes | required |
|---|---|---|
| `warp` | int — the language version this document is written for | no; absent reads as `1` |
| `needs` | array of strings — every word the program *calls* and does not declare; words a path reaches are bounded separately, below | no |
| `name` | string | no |
| `description` | string | no |
| `types` | record: name → type | no |
| `const` | record: name → expression | no |
| `procedures` | record: name → procedure | yes, and not empty |

**The version.** The current version is **1**; the earliest that ever existed is
**1** — pre-release, so the two ends of the reading range are one number. A reader must refuse a document written for a later version than it
implements, before judging the document's shape — a later version may add keys,
and checking shape first would turn "I am too old for this" into "this is
malformed". A document claiming a version below the earliest **refuses**. The
number goes up when anything portable changes what an existing program *means*:
a shape added, a shape read differently, a checking rule moved, a standard word
answering differently. It does not move when a word is *added*, since a program
that does not call it cannot tell, and one that does is refused by name.

What each version was:

| version | what moved |
|---|---|
| 1 | the language as specified here |

An implementation implements the **current** version only. An older document is
read, and held to the current rules — a program that leaned on what moved is
*refused with the reason named*, not quietly run to a different answer, and
that refusal being explicable is what the number buys. Forward compatibility is
not available to anyone: what a reader can do about a version it has never
heard of is refuse, and the point of the number is that it can.

**The needs list.** What the program *sends* and does not itself declare — from
procedure bodies and from constants alike. The list is that set exactly, not a
bound around it: **reading refuses** a document whose list disagrees with what
its program sends, in either direction — a stage-1 refusal, and it can be, since
what a program sends is a fact of its text alone. The list is read before the
program and a caller grants from it, so a list saying less would be trusted and
wrong, and a list saying more asks for a grant the program has no use for.

A document that writes no list makes no claim and is held to none — the words
it sends are still refused at the link when nothing declares them; what is lost
is only the chance to decide before linking. The canonical writer always writes
the list, so a document from a conforming writer always carries its claim, and
a caller that wants one refuses a document without it.

A path (`a.b.count`) reaches words too, and they are **not listed**. A path
only ever reaches a word that answers without running, so nothing a path
reaches escapes the program — which is what keeps the list readable as the
bounds of what a program may *do* — and whether such a word exists is the
link's question, answered at the link by name.

### A procedure

| key | takes | required |
|---|---|---|
| `description` | string | no |
| `parameters` | record: name → parameter | no |
| `receiver` | string — the name of the parameter a path reaches this procedure through | no |
| `returns` | type | no |
| `body` | statements | no |
| `result` | expression — what the procedure answers | no |

A procedure answers what `result` names, and nothing if it names nothing. The
value of the last statement is never the answer.

### A parameter

Written as a bare string — its type — or as a record:

| key | takes | required |
|---|---|---|
| `type` | type | no; absent means `any` |
| `oneOf` | array — the values this parameter admits | no |
| `default` | the value used when the argument is absent | no |
| `hint` | string | no |

`oneOf` is judged wherever an argument is settled against the parameter: at the
**link** for a constant argument, at the run's boundary otherwise. The
declaration itself is judged at the **link**, wherever the parameter is written
— nested signatures included — because a declaration may lean on a declared
type name, and only the link resolves those: a `oneOf` that admits nothing
**refuses** — none of its candidates is a value the declared type could hold,
the empty set being the plainest case — and so does a `default` the parameter
itself would refuse, by its `type` or its own `oneOf`. A `default` written as
`null` is the value the body receives, so it needs a type that admits null. A
taken default arrives **settled**, exactly as a passed argument does. A
parameter without a `default` is required; there is no separate optionality.

### A statement

A record carrying **at most one** naming key and **exactly one** construct key.

The naming key says what the statement does to its name:

| key | means |
|---|---|
| `id` | fixes the name — written once, never again |
| `var` | introduces a name that may be written again |
| `set` | writes a name a `var` declared earlier |

A statement with no naming key runs its construct and binds nothing — the
answer is dropped, which is how an effect is asked for on its own. Two families
step out of this freedom, in opposite directions:

- The constructs that bind **through** the statement's name — `loop` (its
  round), `each` over a collection (its element), `attempt`
  (its failure) — **require** one. With no name there is nothing for the body
  to read those bindings under, and a reader that invented a name would have
  invented a real name somewhere. Writing one nameless **refuses**.
- The leaving constructs (`return`, `break`, `continue`) take **no** naming
  key at all: such a statement never finishes, so its name could never bind,
  and a key that promises a binding that cannot happen **refuses**. The same
  rule reaches a **call**: a statement whose word declares `returns: never`
  binds nothing and takes no name — held at the **link**, because only the
  link knows the signature, where the syntactic leaves are held at the reading.

**One name, several askers.** A statement's name names the statement, and every
reader of it reads that one fact: an expression reads the value the statement
bound; a body inside a binding construct reads the construct's own binding
under it (`walk.item`, `round.index`, `tried.message`); a `break` or `continue`
names the loop statement it ends. These are not three names sharing a spelling
— they are one name, asked three questions, and which question applies is
fixed by where the asker stands. What keeps the readings from colliding is
scope, stated per construct: a walk's name is the element's only inside its
body; a loop's round is readable in its condition, body and result; an
attempt's name binds the failure only while the rescue runs — so the binding
reading and the value reading are never live at the same place.

The construct keys, each detailed below: `value`, `call`, `branch`, `loop`,
`each`, `attempt`, `group`, `return`, `break`, `continue`.

### Statements: the constructs

**`value`** — one expression; the statement binds what it evaluates to.

**`call`** — a message:

| key | takes | required |
|---|---|---|
| `procedure` | string — the word sent | yes |
| `of` | expression — the receiver | no |
| `arguments` | record: name → expression | no |

A body a word is to run travels as a **closure argument**, like any other
value. There is no second channel for bodies: one kind of thing crosses into a
word, and it is the isolated one.

**`branch`** —

| key | takes | required |
|---|---|---|
| `when` | expression — must answer a bool | yes |
| `then` | block | yes |
| `else` | block | no |

Both arms are checked whether or not they are taken.

**`loop`** —

| key | takes | required |
|---|---|---|
| `where` | expression — runs another round while true | yes |
| `body` | statements | yes |
| `result` | expression | no |

The loop's own statement name binds the round it is on, readable everywhere the
loop is still speaking — the `where` condition, the `body`, and the `result`.
The condition reads the state before the round it would start, so `round.index`
there is how many rounds have finished. What a loop answers is its `result`
read in what the last round that *finished* left behind; a round cut short
contributed nothing. A loop naming no result answers nothing.

A loop carries no budget of its own. Bounding one is the author's to write — a
counter in the condition and a word past the bound say it exactly — and
stopping one is the receiver's **cancellation**, under Running below. A kernel
budget would promise neither side anything it could rely on: the author can
already say it, and the receiver could not trust a bound the author chose.

**`each`** —

| key | takes | required |
|---|---|---|
| `in` | expression — a collection | yes |
| `body` | statements | yes |

Walks the collection in order and answers nothing. The statement's name binds
the round (`walk.item`, `walk.index`) and that is all it is — inside the body
it is the element, and after the walk it is not readable, since the only value
it could ever hold is null; `var` and `set` on a walk refuse the same way. A
round's contribution is what it writes to an outer variable. A pure mapping is
`std.collection.map`'s to say; an effectful round with something to keep
writes outward.

There is no concurrency construct. Running things at once is **vocabulary** —
`std.concurrent`, below — because a closure is already the one body that is
safe to run beside another, and "takes closures" is a thing a signature can
say. `each` stays grammar for the opposite reason: its body writes the
enclosing names, and that is exactly what no signature can say. That is also
the line between the walks: reach for `each` when a round writes outward or
leans on the round before it, and for a word — `std.collection.map`, `filter`,
`std.concurrent.map` — when each element's work stands alone, which is what
lets the concurrent `map` run it at once.

**`attempt`** —

| key | takes | required |
|---|---|---|
| `body` | statements | yes |
| `result` | expression | no |
| `rescue` | block — runs if the body fails | yes |

A rescue catches failure — what the world did. It does not catch leaving —
what the program said. A rescue with nothing in it — no statement to run for
effect, no `result` to answer — **refuses at the check**: it would swallow a
failure into null without a trace. This is the one exception to a block's
optional `result`, and the failure is the reason. The statement's own name binds the failure **while the
rescue runs** — and what it binds is a **record**: at least `type` (one word
naming what happened — `aborted`, `concurrent_failed`) and `message` (text for
a person), plus whatever that failure carries —
`concurrent_failed` carries `failures`, every piece's reason keyed by the
piece. A failure is data the moment a rescue holds it, which is why no ninth
kind exists for it.

**`group`** — a block written as a statement, and nothing more: the bare
member of the same family as a `branch` arm or a `loop` round, with the
condition left off. Like any statement it *may* take a name, and its name
binds what its `result` answers. Because a block runs here, once, in the same
flow — a fact the text shows, since no expression can carry a block away — a
group may `set` the enclosing variables, exactly as a `branch` or `loop` body
may, where a closure captures values and writes no name from outside. A fence
for names, not a door to elsewhere. (See *two kinds of body*, under
Concurrency.)

**`return`** — answer the enclosing procedure from here. Takes an expression,
or nothing (`return:` with null) to answer nothing. The answer must fit what
the procedure declared.

**`break`** — end a loop. **`continue`** — end the round and go on to the
next. Each takes a loop's statement name, or nothing for the nearest enclosing
loop. Both **refuse at the check** when nothing encloses them: a closure runs
away from where it was written, so the loops around the writing are
not around the running, and neither crosses into a procedure written inside
another.

Nothing may be written after a `return`, `break` or `continue` in the same
body: it would never run, and the name it would bind would never bind. The same
holds after a call whose word declares `never`, at the link. The rule reaches
through structure, because the fact does: a `branch` both of whose arms leave
never finishes either, so it takes no name and nothing may follow it — held at
the **check**, since the arms are text. A construct that can finish — a branch
with no `else`, a loop, an `attempt` (its rescue may finish normally) — is not
a leave, however its bodies end.

There is no `abort` construct. Failing on purpose is a word —
`std.control.abort`, below — because a signature can say everything checking it
needs: `returns: never` is the whole fact, and a thing is grammar only when
checking it would need to understand more than a signature can say.

### Expressions

A scalar is itself — a literal. A string is always literal text; nothing inside
it is ever re-parsed. An array is an array of expressions. A record is a record
of expressions — **unless** it carries one of the five form keys:

| form | means |
|---|---|
| `{ ref: a.b[0] }` | a name, resolved in the consuming scope; the record must have no other key |
| `{ value: <data> }` | the escape: exactly this data, as a literal, even if it looks like a form |
| `{ call: <message> }` | a message where a value is wanted; same grammar as the `call` construct |
| `{ closure: <procedure> }` | a procedure written where a value is wanted; same grammar as a procedure |
| `{ format:, with: }` | reserved: a front-end spelling (below); **refuses** in a document |

The form keys are fixed. A record that carries one as plain data must be
quoted with `{ value: … }` — quotation is a fact about the document, not about
the expression it writes.

### Blocks

A block is `{ body: <statements>, result: <expression> }`, both optional. A
block answers what its `result` names, and nothing if it names nothing.

## Spellings are not part of the document

A front end may offer shorthands — operator keys like `is:` in a condition
slot, a `{ format:, with: }` template — that stand in for shapes the language
already has. They are the front end's own: it spends them before the document
leaves, and what leaves writes the shapes themselves.

A reader of documents **refuses** the spelled keys rather than reading them as
data. The reserved set is exactly `format` and `with` — an operator key like
`is:` lives inside a condition slot a front end owns and can never reach a
document, so it needs no reservation. The two stay reserved whether or not any
notation offers them — a document that writes one was written *for* a spelled
notation, and reading it as a record that happens to have those fields would
be running a program nobody wrote.

## What an implementation checks, and when

A program is read, checked and linked before any of it runs — including the
arms nobody takes. All of the following are answered while nothing has
happened yet:

- every `ref` resolves to a parameter, a constant, a statement written before
  it, or a path through them;
- every word sent is declared by some module in the link, exactly once;
- every call fits the declaration it reaches: arguments by name, receiver,
  and answer, with holes bound as above;
- every declared type names a type that exists;
- a parameter's `oneOf` admits something, and its `default` is a value the
  parameter itself admits;
- a slot declared `pure` takes only a procedure that answers without running —
  worked out from a body's own sends, declared by a native word;
- a constant is the shape it was declared as;
- `break`/`continue` have a loop, `return` fits the declaration, nothing
  follows any of them;
- a statement that never finishes — a syntactic leave, or a call whose word
  declares `never` — takes no name, and nothing follows it;
- every name the program writes as a value — a statement's, a binding's (a
  loop's round, an iteration's element, an attempt's failure), a parameter's,
  each segment of a `ref` — is **normal form C**, compared as bytes. Record
  *keys* hold this line at the encodings; these are the names that live in
  string values, and this is where they hold it. One name has one byte
  spelling, so a declaration and a reference can only meet by being the same
  bytes — `é` written two ways is a refusal, not two names.

The `needs` list is deliberately not on this list — it is held at *reading*,
above, because a caller decides from it before any of this runs.

**This is not a proof and does not pretend to be.** Whether a number will be
zero when something divides by it is not decided by reading. What moved is the
line between "found out by running" and "found out by reading" — a long way,
not all the way.

An interpreter that reports a defect on the path you happened to take is
sampling, not checking. A program that arrived has branches nobody ran before
sending it, and the one that matters is the one that only fires in production —
there is no opportunity to find out by trying, because trying *is* production.

## Running

- Statements run in order; each binds its name in the scope of what follows.
- A call's arguments are evaluated in **name order**. Almost nothing can
  observe this — arguments evaluate without effects — but two arguments that
  would each refuse surface one refusal, and which one is the text's fact,
  not a hash table's.
- `std.collection.keys` and `values` answer in the record's **canonical
  order** — names ascending — for the same reason: a program that walks them
  gets the same walk on every run.
- A procedure's answer is settled against `returns` at the boundary — a body
  cannot leak a value its declaration did not admit. The half the text already
  shows is held earlier: a **constant** answer that cannot fit the declaration
  refuses at the **link**, the way a constant argument does.
- **A run can always be stopped from outside.** Cancellation is observed
  between statements and at the entry to every round, including a round with
  an empty body. This is the receiver's one lever over consumption, and it is
  the whole of the language's promise about time and memory: a program calling
  only the standard vocabulary can run forever, and nothing here predicts it —
  what is promised is that it can always be told to stop.
- Leaving (`return`/`break`/`continue`) travels out through whatever it is
  inside — and is not a failure: a rescue does not catch it. It does not cross
  a closure's edge: `return` inside a closure answers the closure.

**Concurrency is isolation, and it is granted.** Warp's values are all data,
and a closure can only **read** what it closed over — so the only thing two
bodies running at once could contend for is a written name, and no body that
runs away from where it was written is allowed one:

- **Two kinds of body, told apart by where they are written.** Every
  `body`/`block` slot the document grammar has — `group`, a `branch` arm, a
  `loop` or `each` round, an `attempt`'s body and its `rescue`, all of them,
  present and future — holds a **block**: a body that runs here, in the flow
  that wrote it, and that is visible in the text, because no expression can
  carry a block away. A block may `set` the enclosing variables. The one body
  that becomes a value is the **closure** — a *procedure*, with parameters
  and a declared answer — and a value may cross into a word, where no
  signature can say when, how often, or beside what the word runs it. So the
  split is Swift's non-escaping/`@Sendable` line, carried by spelling instead
  of analysis — the slot *is* the proof of non-escape, and there is nothing
  in between: the one channel into a word is the isolated one. Not two
  flavours of one thing, either: a block has no parameters because a body
  that runs where it stands has nothing to be handed, and a procedure has
  them because crossing a boundary is exactly when arguments exist.
- What a closure captures is the name as it is: a fixed name's **value**, and
  a variable's **box** — Swift's line. Making a closure runs nothing; a
  variable set between the making and the calling is seen by the call,
  because the box is one thing under one name everywhere it is visible. This
  stays raceless because writers are checked away, not because reads are
  frozen: a closure **writes no name from outside** — `set` to one **refuses
  at the check** — and while a word's pieces run, the body that could write
  the variable is suspended at the join. A piece answers a value; combining
  is written after the join, where the names are sequential again.
- Leaving does not cross the boundary either: `return` inside a closure
  answers the closure, and `break`/`continue` aimed past one **refuse at the
  check**. The ground is the `attempt` distinction — a failure is what the
  *world* did, and the world was always concurrent; leaving is what the
  *program* says, and the program does not get to say two things at once.
- Because a closure is already isolated, running closures at once is a thing
  a **word** can be handed — `std.concurrent`, under the vocabulary — and so
  concurrency is a *grant*: a receiver that leaves the bundle out of the link
  has programs that cannot fan out at all. There is no construct to have for
  free.
- What this buys, exactly: **Warp itself writes no race.** It is not "every
  answer is deterministic" — one thing is timing's on purpose, and it is
  named: which piece `first` answers with. Everything else a join answers is
  the same under every interleaving — `all` waits for every piece, so a
  rescue around a fan-out that lost twice is handed every failure, keyed by
  the piece it came from, whichever finished first.
- **Effects are the world's, and the world is the receiver's.** Two pieces'
  host calls interleave in an order nothing states, and two pieces reaching
  one host-held thing — a file, a counter — is contention the *host's* word
  must defend, not the language. The isolation stated here is about the
  language's names, all the way; about the world, only as far as the host's
  own words keep their contracts. A receiver that needs an ordered meeting
  point offers one as a host word, where it can defend it.

There are no lower-level primitives — no spawn, no locks — on purpose: a
program that arrives is a program nobody can debug a race in.

## The standard vocabulary

Six bundles, taken separately, so a receiver grants what its programs have use
for and no more:

| module | words |
|---|---|
| `std.logic` | `equal` `notEqual` `not` `and` `or` |
| `std.math` | `plus` `minus` `times` `dividedBy` `remainder` `min` `max` `absolute` `floored` `rounded` `lessThan` `greaterThan` |
| `std.text` | `text` `startsWith` `regex` `uppercased` `lowercased` `trimmed` `split` `joined` `replacing` |
| `std.collection` | `count` `contains` `first` `last` `reversed` `appending` `prepending` `dropFirst` `dropLast` `sorted` `map` `filter` `reduce` `keys` `values` `setting` |
| `std.control` | `abort` — declared `returns: never` |
| `std.concurrent` | `all` `first` `map` — run closures at once |

**The signatures, exactly.** A second implementation writes these; it must not
have to guess them. The *receiver* column is the parameter a path reaches the
word through (and the `of`/`over` key in a `call`); everything else is written
by name under `arguments`. A parameter with a `default` may be left out. A slot
typed `pure procedure` takes only a procedure that answers without running.

*std.logic*

| word | receiver | arguments | answers |
|---|---|---|---|
| `equal`, `notEqual` | `of: any = null` | `value: any = null` | `bool` |
| `not` | `of: bool` | — | `bool` |
| `and`, `or` | `of: array<pure procedure>` | — | `bool` |

*std.math*

| word | receiver | arguments | answers |
|---|---|---|---|
| `plus`, `minus`, `times`, `remainder`, `min`, `max` | `of: some N` | `value: some N` | `some N` |
| `dividedBy` | `of: some N` | `value: some N` | `double` |
| `absolute` | `of: some N` | — | `some N` |
| `floored`, `rounded` | `of: number` | — | `int` |
| `lessThan`, `greaterThan` | `of: some Ordered` | `value: some Ordered` | `bool` |

*std.text*

| word | receiver | arguments | answers |
|---|---|---|---|
| `text` | `of: any` | — | `string` |
| `startsWith`, `regex` | `of: string` | `value: string` | `bool` |
| `uppercased`, `lowercased`, `trimmed` | `of: string` | — | `string` |
| `split` | `of: string` | `value: string` | `array<string>` |
| `joined` | `of: array<string>` | `value: string = ""` | `string` |
| `replacing` | `of: string` | `value: string`, `with: string` | `string` |

*std.collection*

| word | receiver | arguments | answers |
|---|---|---|---|
| `count` | `of: any` | — | `int` |
| `contains` | `of: any` | `value: any` | `bool` |
| `first`, `last` | `of: array<some Element>` | — | `some Element` |
| `reversed`, `sorted`, `dropFirst`, `dropLast` | `of: array<some Element>` | — | `array<some Element>` |
| `appending`, `prepending` | `of: array<some Element>` | `value: some Element` | `array<some Element>` |
| `map` | `of: array<some Element>` | `value` — pure procedure, offered `item`, answering `some Answer` | `array<some Answer>` |
| `filter` | `of: array<some Element>` | `value` — pure procedure, offered `item`, answering `bool` | `array<some Element>` |
| `reduce` | `of: array<some Element>` | `from: some Carried`; `value` — pure procedure, offered `carried` and `item`, answering `some Carried` | `some Carried` |
| `keys` | `of: object<any>` | — | `array<string>` |
| `values` | `of: object<some Entry>` | — | `array<some Entry>` |
| `setting` | `of: object<any>` | `key: string`, `value: any` | `object<any>` |

*std.control*

| word | receiver | arguments | answers |
|---|---|---|---|
| `abort` | `of: any` — what the refusal says | — | `never` |

*std.concurrent*

| word | receiver | arguments | answers |
|---|---|---|---|
| `all`, `first` | `of: any` — a record or array of closures | — | `any` |
| `map` | `over: array<some Element>` | `by` — procedure, offered `item` and `index`, answering `some Answer` | `array<some Answer>` |

**`std.concurrent`** — running closures at once. `all` takes a record or
an array of closures, runs every one, and answers every answer — a record's
under its keys, an array's in its order; a failure fails the whole word with
every piece's failure reported, keyed by the piece it came from. `first` takes
the same and answers the first success, asking the rest to stop — which piece
wins is the one timing fact this language admits. `map` takes a collection
and one closure, calls it once per element — each call offered `item` and
`index`, and the closure's own signature says which it reads — and answers in
the collection's order. These are words rather than grammar because a closure
is already the safe unit of concurrent work, and being words makes concurrency
a permission: what a receiver does not link, a program cannot do.

The names are plain words with the module carrying the context, the way
`Array.map` and `TaskGroup.next` lean on their types. The rule under them is
the general one: a **bare** word name resolves only while exactly one linked
module declares it; when two do, the bare spelling **refuses at the link**,
naming both, and only the qualified spellings resolve. `first` and `map` are
also declared by `std.collection`, so a link carrying both bundles pays on
*both* sides — every `first` and every `map`, the sequential ones included,
is written qualified. That cost is taken knowingly: the qualified spelling is
the meaning, and concurrency shows at the call site. Paths are untouched: a
path reaches only pure words, and every word here is an effect, so `x.first`
still means the collection's.

What the checking sees: `map` declares its types the way the sequential one
does — the collection's `Element` meets the closure's parameter, and the
answer's type is the closure's answer, checked at the link. `all` and `first`
take and answer `any`, because "a record of closures or an array of them" is a
union no type here can say — the precision is unsayable rather than lost, and
what a fan-out's answer feeds is checked from `map`, not from these two.

What the words offer their closures is one convention, shared with the
sequential walks: a walking word **offers** names — `std.collection.map`
offers `item`, `reduce` offers `carried` and `item`, `std.concurrent.map`
offers `item` and `index` — and the closure's own parameters say which of the
offer it reads. An offered name the closure does not declare is simply not
taken; a parameter the offer does not cover is missing as usual. `first`
run over nothing is refused — a word that answers exactly one thing has no
empty answer — and a `first` in which nothing succeeds fails the way `all`
fails: every piece's failure reported, keyed by the piece it came from.

What the vocabulary answers about **bytes**: they are a **sequence of bytes**,
the way text is a sequence of characters — equal by content, in order, and
counted, with no Unicode question about what "one" means. Reading an element
answers a whole number 0–255; there is no separate byte kind. Two bytes
*values* still do **not** order: `lessThan`, `greaterThan` and `sorted`
refuse them, because ordering two blobs implies a reading and bytes carry
none — the elements are numbers, the whole is not a number. Element access,
slicing, and reading bytes *as* text in a named encoding arrive as words when
something needs them; what is still thin is recorded below.

**`abort`** — fail on purpose, with a message. Declared `returns: never`, which
is everything the checking needs: nothing runs after it, and no name binds it.
The refusal it raises is a failure like any other, so an `attempt` around it
catches it — leaving is what a rescue does not catch, and this is failing, not
leaving.

Behaviour at the edges — where implementations quietly differ, so stated as
requirements:

- Arithmetic takes two of a kind and answers that kind: both sides and the
  answer are one hole. A whole number added to text **refuses at the link**.
- Ordering (`lessThan`, `greaterThan`) compares two of a kind, and text is a
  kind.
- Whole-number arithmetic with no whole answer **refuses at the run**. It does
  not wrap and does not silently widen.
- Fraction arithmetic with no finite answer **refuses at the run** for the
  same reason: infinity is a value the arithmetic can reach and no document
  can carry, and a value that exists only until someone writes it down is not
  an answer.
- `dividedBy` answers a fraction, whole or not. Division by zero **refuses at
  the run**.
- A whole number where a fraction is expected widens; the reverse refuses.

What a host brings beyond these — its own words, and which of them answer
without running — is the host's, and is the boundary to the outside world:
a program reaches nothing except by sending a word the receiver declared.

## Encodings

An encoding is bytes for the document tree. Whatever the encoding, three
promises hold:

1. **A whole number and a fraction are told apart.** However the encoding does
   it, `1` and `1.0` must arrive as the values they were.
2. **The same document is the same bytes.** Writers are canonical: record keys
   are written in one order — **ascending by their UTF-8 bytes** — and every
   value has one spelling. This is what makes a document cacheable, comparable
   and signable. Readers hold the same line: non-canonical bytes **refuse**,
   they are not normalised — were a reader forgiving, one document would have
   many byte spellings again, and what a signature was checked against could
   differ from what the reader went on to read.
3. **Nothing but data.** A procedure value has already run far enough to close
   over a scope; no encoding writes one, and refusing every such value rather
   than only the ones that captured nothing is the decision — it costs an
   author nothing and saves every reader a rule about which captures are empty.
   Infinity and NaN are likewise refused on the way out and on the way in.

Every reader also refuses: bytes after the document ends, bytes that end inside
a value, and nesting deeper than **512** containers. The depth is an exact
bound, not a floor — a document 513 deep is not a document anywhere, so a
writer may rely on the refusal. The bound guards whoever walks the tree after
the reader: readers here are obliged to iterate, but everything downstream of
one — checkers, comparers, hosts — recurses over values in the ordinary way,
and their stacks must not be the sender's to spend.

**Record keys are NFC.** Unicode writes some characters more than one way — a
letter, or the same letter as letter-plus-combining-mark — and a name that had
several byte spellings would break promise 2 quietly: two fields one name, or
one name sorted to two places. So a key must be in Unicode Normalization Form
C, and a key that is not **refuses**. One name, one byte spelling; the
ascending-bytes order is then an order on *names*. ASCII is NFC already, so a
document that never leaves ASCII never meets this rule. String *values* are
data, not names: they travel byte-for-byte as written and are never normalised.

**A document is read whole.** Streaming and incremental decoding are
deliberately not offered: a program is checked whole before any of it runs, so
nothing downstream could act on a prefix anyway. This buys the budget rule:
lengths claimed inside a document are charged against **one budget — the byte
count of the document itself** — at the cheapest cost a claimed thing could
possibly occupy on the wire, and a claim the budget cannot cover **refuses**
before anything is set aside for it. Nested containers cannot each claim the
whole document, and no document can make a reader hold more than a small
multiple of its own size.

**Compact was the goal that lost.** In a small document most bytes are field
names, and the format leaves them there: a key table would give one document an
inline spelling and a referenced spelling — promise 2 gone — and schemas are a
meaning the encodings must not learn. Of canonical, self-contained and
compact, the encodings choose the first two; repeated names compress well, and
compression is the transport's job.

An encoding's header carries the *encoding's* format version, distinct from the
document's `warp` key: the one says how the bytes are laid out, the other says
what the program means. A reader refuses bytes laid out by a later format than
it implements, and a format number that never existed.

### Warp binary — `.warp`

The carrying form: what a document travels as. Current format: **1**.

```
"W" "A" "R" "P"  0x01        magic, then the format version
<value>                       exactly one, then end of input
```

Each value is a tag byte, then its payload:

| tag | value | payload |
|---|---|---|
| `0x00` | null | — |
| `0x01` | false | — |
| `0x02` | true | — |
| `0x03` | int | ZigZag, then unsigned LEB128 |
| `0x04` | double | 8 bytes, IEEE-754 binary64, big-endian |
| `0x05` | string | length varint, then that many bytes of UTF-8 |
| `0x06` | array | count varint, then that many values |
| `0x07` | record | count varint, then that many of: key (length varint + UTF-8), value |
| `0x08` | bytes | length varint, then that many raw bytes |

- **Varint** is unsigned LEB128: seven bits a byte, low bits first, high bit
  says another byte follows. At most 64 bits of payload; a tenth byte, or a
  tenth-byte bit that would carry past bit 63, **refuses** — overflow is not
  wrapped, masked or truncated. A trailing zero group (`0x80 0x00` for zero)
  is a longer spelling of the same number and **refuses** — one value, one
  spelling.
- **ZigZag** maps signed to unsigned: `(n << 1) ^ (n >> 63)`.
- Record keys are **strictly ascending** by UTF-8 bytes — which refuses a
  shuffle and a duplicate with the same rule: these are bytes the writer would
  not write.
- A claimed length larger than the bytes that remain **refuses** before
  anything is set aside for it.
- Invalid UTF-8 in a string **refuses**.

The golden case (also held as a test in each implementation):

```
{ "a": 1, "b": [true, null], "c": "hi", "d": 1.5, "e": x"6a73" }

57 41 52 50 01                    WARP, format 1
07 05                             a record of five
01 61 03 02                       "a": int 1        (zigzag 2)
01 62 06 02 02 00                 "b": [true, null]
01 63 05 02 68 69                 "c": "hi"
01 64 04 3F F8 00 00 00 00 00 00  "d": 1.5
01 65 08 02 6A 73                 "e": two bytes
```

### Warp text — `.warpt`

The readable form: the same document laid out for eyes. **A dump, not a
syntax** — machines write it, people read it, and nobody composes one by hand;
composing is a front end's job, in a front end's notation. Nothing can be said
here that the document does not hold, which is why there are no comments to
lose on the way back. Current format: **1**.

```
warpt 1
{
  a 1
  b [
    true
    null
  ]
  c "hi"
  d 1.5
  e x"6a73"
}
```

The layout:

- The first line is `warpt`, a space, the format version, a newline.
- A record is `{ key value … }`; an array is `[ value … ]` — no commas, no
  colons. Containers with anything in them take two-space indentation, one
  element or field per line; empty containers are inline as `[]` / `{}`. The
  text ends with one newline.
- A key is written bare when it is a word (`[A-Za-z_][A-Za-z0-9_]*`), quoted
  otherwise. In key position a bare word is always a key — `{ null 1 }` is a
  field called null.
- `null`, `true` and `false` are bare words. **A number with a point or an
  exponent is a fraction; with neither it is whole** — the difference is
  grammar, not a reader's guess. A double is spelled as the shortest decimal
  that reads back to the same binary64 (a Ryū/Grisu-class rendering), with
  the point or exponent always present; an int is spelled with no leading
  zeros and a `-` only when negative.
- A string is double-quoted. Exactly `"` `\` and the five characters with
  short escapes are escaped as `\"` `\\` `\n` `\r` `\t`; every other control
  character (below U+0020) as `\uXXXX` with lowercase hex; **nothing else is
  escaped**, and no character that has a shorter escape may take a longer one.
- Bytes are `x"…"` — lowercase hex, two digits a byte, no spaces.

And the rule that makes it an encoding rather than a syntax: **a text is the
document's canonical writing or it is not a document.** One document, one text
— byte for byte, the same promise the binary keeps — so a fraction written
`1.50`, a key out of order, an escape spelled long, or an indent of three
spaces all **refuse**. A reader may check this however it likes; writing the
value it read back out and comparing the bytes is enough.

## Conformance

The rules above, as cases that run: `conformance/`. Each case is data — a
document, what to run it with, and what must happen — so a runner is a small
amount of code in whatever language an implementation is written in, and the
questions asked are the same ones. Half the cases say what must *not* run, and
at which stage it must stop.

The cases are written as `.warpt`, so the first thing a new implementation
reads with its own reader is the suite itself. The reader is proven first, by
the golden cases above — an implementation whose reader disagrees with the
golden bytes cannot trust anything the rest of the suite tells it.

A runner imports what any caller imports. One that could see inside its
implementation could pass by agreeing with the implementation rather than with
the specification, which is the one thing it must not do.

## Known gaps

Written down because a specification that hides what it has not decided is
worse than one that admits it. Each is a place a second implementation would
have to guess, and would be entitled to guess differently.

- **The value model is stated further than it is settled.** Where `any`
  admits, when a record carrying more fields fits one that declared fewer, and
  what a declared name accepts are answered by the Swift implementation and
  its tests, not yet here.
- **A hole cannot say what it will take.** Both sides of `lessThan` are one
  reading, but nothing says the reading must be orderable — so comparing two
  booleans refuses at the run rather than at the check. The sameness half of
  the idea is expressible and the constraint half is not.
- **The text decision is cheap in Swift and dear elsewhere.** Grapheme-cluster
  counting and canonical equivalence are the platform's gift in Swift and a
  library obligation in most other languages; the decision stands, and the
  cost lands on implementations unevenly.
- **The document grammar above was written from the readers.** Field tables
  transcribed from one implementation carry its blind spots; the first reader
  who implements from these tables alone, and disagrees, is worth more than
  any amount of agreement.
- **The suite covers the constructs and samples the vocabulary.** Every
  construct, the naming and leaving rules, the envelope, the boundary
  settlements and the concurrency grant are held as cases; the standard words
  are held by representatives, not word-by-word, and cancellation cannot be a
  data case at all — it needs a caller with a lever. What a case does not pin
  is held only by tests inside the Swift implementation.
- **Two equivalences coexist, and the border is drawn.** Values compare as a
  person reads — `equal`, `contains`, ordering and `count` all read text
  under canonical equivalence, stated under the value model — where names are
  matched as bytes, held to NFC at the check, so a document cannot declare
  `é` one way and reference it the other. What remains here is only the cost:
  an implementation whose platform compares by code unit owes a library the
  difference.
- **Canonical bytes and value sameness pull apart at the edges.** `1` and
  `1.0` are one value to a program and two byte strings to the encoding, so
  two documents a program cannot tell apart carry two signatures — intended,
  but unstated. And comparing a 64-bit whole to a binary64 fraction "by
  worth" is exact only below 2^53; above it, what exactness is required of
  the comparison is unstated.
- **A field and a word can contest one path.** `a.b.count` where `b` is a
  record that happens to carry a `count` field: which wins is unstated.
- **The bytes vocabulary is thin.** The shape is decided: a sequence of
  numbers 0–255, equal by content, counted, no order between two bytes
  values. Undecided is the vocabulary over that shape — element access,
  slicing, membership, and the words that read bytes as text in a named
  encoding and back. Today anything beyond the decided refuses, and a second
  implementation should not have to guess what comes next.
