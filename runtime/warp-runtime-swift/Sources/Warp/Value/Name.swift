//
//  Name.swift
//  Warp
//
//  Created by JSilver on 8/21/26.
//

import Foundation

// What being a name costs: one spelling. Unicode writes `é` two ways — one
// scalar, or `e` plus a combining mark — and the two look identical while
// comparing as different bytes. A name is normal form C or it is refused, so a
// declaration and a reference can only meet by being the same bytes.
//
// One predicate rather than one per checker, because the rule is the
// language's and not any checker's own: the encodings hold record keys to it,
// and validation holds every name a program writes as a value to it, and both
// have to mean the same thing by "normal".
public enum Name {
    // MARK: - Property
    // MARK: - Public
    // Compared as bytes on purpose: Swift's `==` compares under canonical
    // equivalence, which would call two spellings equal — the confusion being
    // refused.
    public static func isNormal(_ name: String) -> Bool {
        name.precomposedStringWithCanonicalMapping.utf8.elementsEqual(name.utf8)
    }

    // MARK: - Private
}
