// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation

extension Store where StoreFeature: EmptyInitializing {
    /// Creates a root store using the feature's default initializer.
    public convenience init(state: StoreFeature.State) where StoreFeature.Event == Never {
        self.init(state: state, feature: { StoreFeature() })
    }

    /// Creates a root store using the feature's default initializer.
    public convenience init(state: StoreFeature.State, onEvent: @escaping RootEventHandler) {
        self.init(state: state, feature: { StoreFeature() }, onEvent: onEvent)
    }
}

extension Store {
    /// Returns a child store scoped to a sub-state using the child feature's default initializer, with no event handling.
    public func scope<ChildFeature: Feature & EmptyInitializing>(
        _ keyPath: WritableKeyPath<StoreFeature.State, ChildFeature.State>
    ) -> Store<ChildFeature> where ChildFeature.State: Equatable, ChildFeature.Event == Never {
        scope(keyPath, feature: { ChildFeature() })
    }

    /// Returns a child store scoped to a sub-state using the child feature's default initializer, forwarding child events to the parent.
    public func scope<ChildFeature: Feature & EmptyInitializing>(
        _ keyPath: WritableKeyPath<StoreFeature.State, ChildFeature.State>,
        onEvent: @escaping ChildEventHandler<ChildFeature>
    ) -> Store<ChildFeature> where ChildFeature.State: Equatable {
        scope(keyPath, feature: { ChildFeature() }, onEvent: onEvent)
    }

    /// Returns a child store scoped to an optional sub-state using the child feature's default initializer, with no event handling, or nil if absent.
    public func scope<ChildFeature: Feature & EmptyInitializing>(
        _ keyPath: WritableKeyPath<StoreFeature.State, ChildFeature.State?>
    ) -> Store<ChildFeature>? where ChildFeature.State: Equatable, ChildFeature.Event == Never {
        scope(keyPath, feature: { ChildFeature() })
    }

    /// Returns a child store scoped to an optional sub-state using the child feature's default initializer, forwarding child events to the parent, or nil if absent.
    public func scope<ChildFeature: Feature & EmptyInitializing>(
        _ keyPath: WritableKeyPath<StoreFeature.State, ChildFeature.State?>,
        onEvent: @escaping ChildEventHandler<ChildFeature>
    ) -> Store<ChildFeature>? where ChildFeature.State: Equatable {
        scope(keyPath, feature: { ChildFeature() }, onEvent: onEvent)
    }
}
