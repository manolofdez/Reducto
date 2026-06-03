// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation

extension Store {
    /// Synchronously applies a mutation without returning an event.
    public func apply(_ reduce: (StoreFeature, inout StoreFeature.State) -> Void) {
        apply {
            reduce($0, &$1)
            return nil
        }
    }

    /// Asynchronously performs work without applying a state mutation.
    @discardableResult
    public func apply(
        _ apply: @escaping (StoreFeature, StoreFeature.State) async -> Void
    ) -> Task<Void, Never> where StoreFeature.Event == Never {
        self.apply { feature, state in
            await apply(feature, state)
            return nil
        }
    }

    /// Returns a child store scoped to a sub-state with no event handling (for features with `Never` events).
    public func scope<ChildFeature: Feature>(
        _ keyPath: WritableKeyPath<StoreFeature.State, ChildFeature.State>,
        feature: @escaping () -> ChildFeature
    ) -> Store<ChildFeature> where ChildFeature.State: Equatable, ChildFeature.Event == Never {
        scope(
            keyPath,
            feature: feature,
            onEvent: { event, _, _ in
                event
            }
        )
    }

    /// Returns a child store scoped to an optional sub-state with no event handling, or nil if absent.
    public func scope<ChildFeature: Feature>(
        _ keyPath: WritableKeyPath<StoreFeature.State, ChildFeature.State?>,
        feature: @escaping () -> ChildFeature
    ) -> Store<ChildFeature>? where ChildFeature.State: Equatable, ChildFeature.Event == Never {
        scope(
            keyPath,
            feature: feature,
            onEvent: { event, _, _ in
                event
            }
        )
    }
}
