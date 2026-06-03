// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation

/// A store derived from a parent store, focused on an optional sub-state via a key path.
/// Reads reflect the current parent state when present, or the last known state as a fallback.
/// Sends are dropped when the optional slot is nil.
@Observable
final class OptionalScopedStore<ParentFeature: Feature, ChildFeature: Feature>: InternalStoring
where ChildFeature.State: Equatable {
    typealias DeferredStateMutation = (inout ChildFeature.State) -> ChildFeature.Event?
    typealias EventHandler = (
        _ childEvent: ChildFeature.Event,
        _ parentFeature: ParentFeature,
        _ parentState: inout ParentFeature.State
    ) -> ParentFeature.Event?

    var state: ChildFeature.State {
        get { parentStore.state[keyPath: toChildKeyPath] ?? lastKnownState }
        set {
            lastKnownState = newValue
            parentStore.state[keyPath: toChildKeyPath] = newValue
        }
    }

    private let parentStore: any InternalStoring<ParentFeature>
    private let toChildKeyPath: WritableKeyPath<ParentFeature.State, ChildFeature.State?>
    private var lastKnownState: ChildFeature.State
    private let feature: ChildFeature
    private let onEvent: EventHandler

    init(
        parent parentStore: any InternalStoring<ParentFeature>,
        keyPath toChildKeyPath: WritableKeyPath<ParentFeature.State, ChildFeature.State?>,
        initialState: ChildFeature.State,
        feature: @escaping () -> ChildFeature,
        onEvent: @escaping EventHandler
    ) {
        self.parentStore = parentStore
        self.toChildKeyPath = toChildKeyPath
        self.lastKnownState = initialState
        self.feature = feature()
        self.onEvent = onEvent
    }

    func apply(_ reduce: (ChildFeature, inout ChildFeature.State) -> ChildFeature.Event?) {
        guard parentStore.state[keyPath: toChildKeyPath] != nil else { return }

        var state = self.state
        let event = reduce(feature, &state)

        parentStore.state[keyPath: toChildKeyPath] = state

        guard let event else { return }

        parentStore.apply { parentFeature, parentState in
            onEvent(event, parentFeature, &parentState)
        }
    }

    func apply(
        _ apply: @escaping (ChildFeature, ChildFeature.State) async -> DeferredStateMutation?
    ) -> Task<Void, Never> {
        Task { @MainActor in
            guard self.parentStore.state[keyPath: self.toChildKeyPath] != nil else { return }

            let snapshotState = self.state

            guard let mutation = await apply(self.feature, snapshotState) else { return }

            guard self.parentStore.state[keyPath: self.toChildKeyPath] != nil else { return }

            var state = self.state
            let event = mutation(&state)

            self.parentStore.state[keyPath: self.toChildKeyPath] = state

            guard let event else { return }

            self.parentStore.apply { parentFeature, parentState in
                self.onEvent(event, parentFeature, &parentState)
            }
        }
    }
}
