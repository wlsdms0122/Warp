//
//  ConstructRegistry.swift
//  WarpDocument
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

// The keyword table: which word a document may write, and which form reads it.
// The language's constructs are anonymous, so this is the only place that
// admits they have names.
//
// A form's `key` is the spelling it proposes, not the one it gets. The table is
// what a notation *is*, so the composer of the table has the last word: the same
// form can be registered under another spelling, and a built-in spelling can be
// dropped. Otherwise a form type would be its own name forever, and two
// notations that wanted the same word could never both exist — which is a fact
// about a `static let`, not about the language.
public struct ConstructRegistry: Sendable {
    // MARK: - Property
    // The built-in set is a compile-time constant with unique keys — a throw here
    // would be a kernel bug, so the forced try is the honest reaction.
    public static let standard = try! ConstructRegistry(forms: [
        ValueForm.self,
        BranchForm.self,
        LoopForm.self,
        EachForm.self,
        GroupForm.self,
        AttemptForm.self,
        CallForm.self,
        InvokeForm.self,
        ReturnForm.self,
        BreakForm.self,
        ContinueForm.self
    ])

    public var keys: [String] { forms.keys.sorted() }

    // What the registered forms send. Dropping a form drops what it required,
    // which is the point of the table being a value.
    public func vocabulary(with spellings: SpellingRegistry) -> Set<String> {
        forms.values.reduce(into: Set()) { words, form in
            words.formUnion(form.vocabulary(with: spellings))
        }
    }

    private var forms: [String: any ConstructForm.Type]

    // MARK: - Initializer
    public init(forms: [any ConstructForm.Type] = []) throws {
        self.forms = [:]

        for form in forms {
            try insert(form, as: form.key)
        }
    }

    // The same table written as words rather than forms, for a notation that is
    // spelling most of it itself.
    public init(forms: [String: any ConstructForm.Type]) throws {
        self.forms = [:]

        for (key, form) in forms {
            try insert(form, as: key)
        }
    }

    // MARK: - Public
    // Passing a key spells this form differently in this notation. Registering
    // one form twice is an alias rather than a mistake — the table maps words to
    // forms, and nothing says two words cannot mean the same thing.
    public func registering(
        _ form: any ConstructForm.Type,
        as key: String? = nil
    ) throws -> ConstructRegistry {
        var registry = self

        try registry.insert(form, as: key ?? form.key)

        return registry
    }

    // Giving up a word. A notation that wants `branch` to mean something of its
    // own has to be able to stop meaning ours by it, and respelling a built-in is
    // this followed by `registering(_:as:)` — the reason a rename is a change to
    // a table here rather than a change to the language.
    public func removing(_ key: String) -> ConstructRegistry {
        var registry = self

        registry.forms[key] = nil

        return registry
    }

    public func form(for key: String) -> (any ConstructForm.Type)? {
        forms[key]
    }

    // The table read backwards, for writing a document rather than reading one.
    //
    // A form registered under two words is spelled with whichever sorts first.
    // An alias says the words mean the same thing and not which one is meant, so
    // there is nothing here to prefer — and a table is unordered anyway, which
    // makes "the one registered first" a thing this cannot know. What matters is
    // that the answer is the same every time, since a document written twice has
    // to come out the same both times.
    //
    // Nothing where the form is not registered: a notation that gave up a word
    // cannot write what that word said, and answering with the built-in spelling
    // would put a key in the document that reading it back would refuse.
    public func key(for form: any ConstructForm.Type) -> String? {
        forms.filter { _, registered in
            ObjectIdentifier(registered) == ObjectIdentifier(form)
        }
        .keys
        .min()
    }

    // MARK: - Private
    // A key is claimed once — silently replacing a form would let a caller swap
    // out the language's own control structures without a trace. Deliberately
    // replacing one is `removing(_:)` first, which leaves the intent written down.
    private mutating func insert(_ form: any ConstructForm.Type, as key: String) throws {
        guard forms[key] == nil else {
            throw ValidationError("construct key '\(key)' is already registered")
        }

        forms[key] = form
    }
}
