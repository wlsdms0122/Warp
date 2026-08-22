//
//  TemplateSegment.swift
//  WarpDocument
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Warp

public enum TemplateSegment: Sendable, Equatable {
    case text(String)
    case ref(path: [PathSegment])
}
