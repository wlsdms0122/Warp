//
//  Symbol.swift
//  Warp
//
//  Created by JSilver on 8/17/26.
//

import Foundation

// One declaration, together with where it was declared. The linker needs the
// second half: a name written inside a module means that module's declaration
// first, so resolving a call takes the call's origin and not only its spelling.
struct Symbol: Sendable {
    // MARK: - Property
    // What this declaration is called across the whole link. `module.name` where
    // the module has a name, and the bare name where it has none — a module the
    // caller never named has nothing to qualify with, so it declares into the
    // shared space the way a translation unit without a namespace does.
    let qualified: String

    // Which module declared it, by position in the link. Identity rather than
    // name, so two unnamed modules are still two modules.
    let origin: Int

    let procedure: Procedure

    // MARK: - Initializer
    // MARK: - Public
    // Whether this declaration answers to a bare name — the spelling a module
    // uses for its own, and the one another module may use when nothing else
    // declares it.
    func declares(_ name: String) -> Bool {
        qualified == name || qualified.hasSuffix(".\(name)")
    }

    // MARK: - Private
}
