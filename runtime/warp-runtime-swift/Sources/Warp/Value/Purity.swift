//
//  Purity.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// What a slot requires of a procedure that stands in it.
//
// The runtime knows which procedures answer without running — the linker works
// it out for bodies and a native declares it — but until this, nothing could
// *ask* for one. A word that runs its argument inside a condition or a path
// needs an argument that can be run there, and `procedure` alone does not say
// so.
public enum Purity: Sendable, Equatable {
    // No claim. Either kind fits, the way `any` fits any value.
    case unstated

    // Must answer without running. What stands here may be asked wherever a
    // value is read rather than run.
    case pure
}
