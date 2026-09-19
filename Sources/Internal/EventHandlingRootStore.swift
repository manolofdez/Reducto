// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Combine
import Foundation

/// A root store for a feature that emits events. Since a root has no parent to bubble to, the events
/// are handled in place by `onEvent`, within the same transaction as the mutation that produced them.
@Observable
final class EventHandlingRootStore<RootFeature: Feature>: InternalStoring {
    typealias EventHandler = (
        _ event: RootFeature.Event,
        _ rootFeature: RootFeature,
        _ rootState: inout RootFeature.State
    ) -> Void

    var state: RootFeature.State {
        didSet { subject.send(state) }
    }
    var publisher: AnyPublisher<RootFeature.State, Never> {
        subject.eraseToAnyPublisher()
    }

    let feature: RootFeature

    private let subject: CurrentValueSubject<RootFeature.State, Never>
    private let onEvent: EventHandler

    init(
        initialState state: RootFeature.State,
        feature: @escaping () -> RootFeature,
        onEvent: @escaping EventHandler
    ) {
        self.state = state
        self.subject = CurrentValueSubject(state)
        self.feature = feature()
        self.onEvent = onEvent
    }

    func apply(_ reduce: (RootFeature, inout RootFeature.State) -> RootFeature.Event?) {
        var state = state

        if let event = reduce(feature, &state) {
            onEvent(event, feature, &state)
        }

        self.state = state
    }
}
