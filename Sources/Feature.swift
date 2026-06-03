// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation

/// Abstraction for a feature module. Calling functions on the Feature mutates the state.
public protocol Feature {
    associatedtype State
    associatedtype Event
}

public extension Feature {
    typealias Event = Never
}
