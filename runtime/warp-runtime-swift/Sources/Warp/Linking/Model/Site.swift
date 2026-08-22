//
//  Site.swift
//  Warp
//
//  Created by JSilver on 8/19/26.
//

import Foundation

// A place in a body that asks the link a question. There are two, because there
// are two ways to name something that has to exist: sending to a selector, and
// drilling through a path. Reading a body gathers both, and both are answered
// where names resolve — the walk itself decides nothing.
enum Site: Sendable {
    case call(CallSite)
    case reach(ReachSite)
}
