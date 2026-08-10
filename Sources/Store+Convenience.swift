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

    /// Asynchronously performs work that can apply multiple state mutations via the provided callback.
    /// Convenience for features with `Never` events — the callback does not require returning an event.
    public func apply(
        id: some Hashable = UUID(),
        _ work: @escaping (StoreFeature, @escaping ((inout StoreFeature.State) -> Void) -> Void) async -> Void
    ) where StoreFeature.Event == Never {
        self.apply(id: id) { feature, apply in
            let simpleApply: ((inout StoreFeature.State) -> Void) -> Void = { stateChange in
                apply { state in stateChange(&state); return nil }
            }
            await work(feature, simpleApply)
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
