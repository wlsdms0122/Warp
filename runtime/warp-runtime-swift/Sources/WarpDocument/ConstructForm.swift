//
//  ConstructForm.swift
//  WarpDocument
//
//  Created by JSilver on 8/8/26.
//

import Foundation
import Warp

// How a document spells a construct. A keyword and an expression meet here and
// nowhere else — the language's own constructs have no names, and this is the
// one surface that says which word builds which.
//
// A form is asked for its expression with the name it is being bound under,
// because two constructs need a name to exist inside their body and this
// notation supplies the statement's own id for it: `loop` binds round state,
// `each` binds the element. In the IR those names are written down; here they
// are inherited from the envelope, which is why the reader hands one over.
public protocol ConstructForm: Sendable, Decodable {
    // The spelling this form proposes. `ConstructRegistry` may register it under
    // another, so a form never learns which word actually reached it — a word is
    // a fact about a notation, and a form is not one.
    static var key: String { get }

    // Words this form's expression sends, which a link has to declare for the
    // spelling to reach anything. Most forms build the language's own constructs
    // and send nothing, so most leave this empty.
    //
    // It is asked with the spellings on offer because some of what a form spends
    // is spent on its behalf: a slot that reads a condition spends whatever the
    // condition spellings reach, and a notation offering none spends nothing
    // there.
    static func vocabulary(with spellings: SpellingRegistry) -> Set<String>

    // Throws when the form cannot be the statement it was written as — the
    // one case today being a form that binds through the statement's name,
    // handed no name to bind through.
    func expression(boundTo id: String?) throws -> Expression
}

public extension ConstructForm {
    static func vocabulary(with spellings: SpellingRegistry) -> Set<String> { [] }

    // The name a binding construct binds through. It is the statement's own —
    // which is why these constructs cannot be written nameless: with no name,
    // what the body binds would have to be invented, and an invented name is a
    // real name somewhere.
    func named(_ id: String?, in construct: String, binding: String) throws -> String {
        guard let id else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: [],
                    debugDescription: "a \(construct) binds its \(binding) under the"
                        + " statement's name, so it cannot be written nameless"
                )
            )
        }

        return id
    }
}
