// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Combine
import Foundation
import os.log

/// A store derived from a parent store, focused on an optional sub-state via a key path.
/// Reads reflect the current parent state when present, or the last non-nil state seen as a fallback.
/// Sends are dropped when the optional slot is nil.
@Observable
final class OptionalScopedStore<ParentFeature: Feature, ChildFeature: Feature>: InternalStoring
where ChildFeature.State: Equatable {
    var state: ChildFeature.State {
        get { parentStore.state[keyPath: toChildKeyPath] ?? lastKnownState }
        set {
            guard parentStore.state[keyPath: toChildKeyPath] != nil else {
                LogUtils.showLog(
                    message: "State update ignored: optional state is nil, cannot apply mutation",
                    category: "OptionalScopedStore"
                )
                return
            }
            parentStore.state[keyPath: toChildKeyPath] = newValue
        }
    }
    
    let publisher: AnyPublisher<ChildFeature.State, Never>
    let feature: ChildFeature
    
    private let parentStore: any InternalStoring<ParentFeature>
    private let toChildKeyPath: WritableKeyPath<ParentFeature.State, ChildFeature.State?>
    private let onEvent: ChildEventHandler<ParentFeature, ChildFeature>
    
    @ObservationIgnored
    private var lastKnownState: ChildFeature.State

    @ObservationIgnored
    private var lastKnownStateCancellable: AnyCancellable?

    init(
        parent parentStore: any InternalStoring<ParentFeature>,
        keyPath toChildKeyPath: WritableKeyPath<ParentFeature.State, ChildFeature.State?>,
        initialState: ChildFeature.State,
        feature: @escaping () -> ChildFeature,
        onEvent: @escaping ChildEventHandler<ParentFeature, ChildFeature>
    ) {
        self.parentStore = parentStore
        self.toChildKeyPath = toChildKeyPath
        self.lastKnownState = initialState
        self.feature = feature()
        self.onEvent = onEvent
        // Note a nil value means the child is being torn down
        self.publisher = parentStore.publisher
            .compactMap { $0[keyPath: toChildKeyPath] }
            .eraseToAnyPublisher()

        // Note the value can change from many places (this store, parent reducers, event handlers), so track
        // it from the parent's publisher rather than at each write site. This assumes synchronous emission from publisher.
        lastKnownStateCancellable = publisher.sink { [weak self] state in
            self?.lastKnownState = state
        }
    }

    func apply(_ reduce: (ChildFeature, inout ChildFeature.State) -> ChildFeature.Event?) {
        guard var state = parentStore.state[keyPath: toChildKeyPath] else {
            LogUtils.showLog(
                message: "Action ignored: can't apply an action without a state",
                category: "OptionalScopedStore"
            )
            return
        }

        let event = reduce(feature, &state)

        parentStore.state[keyPath: toChildKeyPath] = state

        guard let event else { return }

        parentStore.apply { parentFeature, parentState in
            onEvent(event, parentFeature, &parentState)
        }
    }
}
