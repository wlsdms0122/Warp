//
//  Spelling.swift
//  WarpDocument
//
//  Created by JSilver
//

import Foundation

// The words this notation reaches without the author naming them. `is` is a
// spelling; `std.logic.equal` is what answers it, and nobody writing `is` typed
// that.
//
// Every name here is qualified, because a name the author did not write must not
// be found by searching. An unqualified selector is resolved against the calling
// module first, so a document that happened to declare `equal` would quietly
// take over its own `is` — a break with no visible cause, since the two share no
// letters. A qualified name is matched rather than searched, and two modules
// claiming it is a refused link instead of a silent winner.
//
// They live in one table rather than beside the readers that lower them: a
// notation's debt is one fact about the notation, and collecting it from
// wherever it happened to be written is how a later reader's words go unowed.
//
// This is the catalogue rather than the choice. Which of these a notation
// actually offers is `SpellingRegistry`; what stays fixed here is that these keys
// are spellings at all, so a notation dropping one refuses the key rather than
// letting it mean something else.
public enum Spelling {
    // MARK: - Property
    // Condition operators the notation names itself. Anything else written as an
    // operator is already a word's own name and passes through untouched.
    public static let operators = [
        "all_of": "std.logic.and",
        "any_of": "std.logic.or",
        "not": "std.logic.not",
        "is": "std.logic.equal",
        "is_not": "std.logic.notEqual",
        "one_of": "std.collection.contains",
        "present": "std.logic.notEqual"
    ]

    // What interpolation is made of: every piece asked how it reads, and the
    // pieces written one after another.
    public static let read = "std.text.text"
    public static let joined = "std.text.joined"

    // What a template spends, for a notation that offers one.
    public static let interpolation: Set<String> = [read, joined]

    // MARK: - Initializer
    // MARK: - Public
    // MARK: - Private
}
