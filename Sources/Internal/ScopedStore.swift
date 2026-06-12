// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Combine
import Foundation

/// A store derived from a parent store, focused on a sub-state via a key path.
/// Reads always reflect the current parent state, and sends write back through it.
@Observable
final class ScopedStore<ParentFeature: Feature, ChildFeature: Feature>: InternalStoring
where ChildFeature.State: Equatable {
    typealias DeferredStateMutation = (inout ChildFeature.State) -> ChildFeature.Event?
    typealias EventHandler = (
        _ childEvent: ChildFeature.Event,
        _ parentFeature: ParentFeature,
        _ parentState: inout ParentFeature.State
    ) -> ParentFeature.Event?

    var state: ChildFeature.State {
        get { parentStore.state[keyPath: toChildKeyPath] }
        set { parentStore.state[keyPath: toChildKeyPath] = newValue }
    }

    let publisher: AnyPublisher<ChildFeature.State, Never>
    
    private let parentStore: any InternalStoring<ParentFeature>
    private let toChildKeyPath: WritableKeyPath<ParentFeature.State, ChildFeature.State>
    private let feature: ChildFeature
    private let onEvent: EventHandler

    init(
        parent parentStore: any InternalStoring<ParentFeature>,
        keyPath toChildKeyPath: WritableKeyPath<ParentFeature.State, ChildFeature.State>,
        feature: @escaping () -> ChildFeature,
        onEvent: @escaping EventHandler
    ) {
        self.parentStore = parentStore
        self.toChildKeyPath = toChildKeyPath
        self.feature = feature()
        self.onEvent = onEvent
        self.publisher = parentStore.publisher
            .map { $0[keyPath: toChildKeyPath] }
            .eraseToAnyPublisher()
    }

    func apply(_ reduce: (ChildFeature, inout ChildFeature.State) -> ChildFeature.Event?) {
        var state = self.state
        let event = reduce(feature, &state)

        parentStore.state[keyPath: toChildKeyPath] = state

        guard let event else { return }

        parentStore.apply { parentFeature, parentState in
            onEvent(event, parentFeature, &parentState)
        }
    }

    func apply(_ apply: @escaping (ChildFeature, ChildFeature.State) async -> DeferredStateMutation?) -> Task<Void, Never> {
        Task { @MainActor in
            guard let mutation = await apply(self.feature, self.state) else { return }

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
