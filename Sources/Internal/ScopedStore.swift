// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Combine
import Foundation

/// A store derived from a parent store, focused on a sub-state via a key path.
/// Reads always reflect the current parent state, and sends write back through it.
@Observable
final class ScopedStore<ParentFeature: Feature, ChildFeature: Feature>: InternalStoring
where ChildFeature.State: Equatable {
    var state: ChildFeature.State {
        get { parentStore.state[keyPath: toChildKeyPath] }
        set { parentStore.state[keyPath: toChildKeyPath] = newValue }
    }

    let publisher: AnyPublisher<ChildFeature.State, Never>
    
    @ObservationIgnored
    private(set) lazy var feature: ChildFeature = createFeature()
    
    private let parentStore: any InternalStoring<ParentFeature>
    private let toChildKeyPath: WritableKeyPath<ParentFeature.State, ChildFeature.State>
    private let onEvent: ChildEventHandler<ParentFeature, ChildFeature>
    private let createFeature: () -> ChildFeature

    init(
        parent parentStore: any InternalStoring<ParentFeature>,
        keyPath toChildKeyPath: WritableKeyPath<ParentFeature.State, ChildFeature.State>,
        feature createFeature: @escaping () -> ChildFeature,
        onEvent: @escaping ChildEventHandler<ParentFeature, ChildFeature>
    ) {
        self.parentStore = parentStore
        self.toChildKeyPath = toChildKeyPath
        self.createFeature = createFeature
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
}
