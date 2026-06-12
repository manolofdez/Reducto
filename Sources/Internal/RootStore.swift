// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Combine
import Foundation

@Observable
final class RootStore<RootFeature: Feature>: InternalStoring where RootFeature.Event == Never {
    var state: RootFeature.State {
        didSet { subject.send(state) }
    }
    var publisher: AnyPublisher<RootFeature.State, Never> {
        subject.eraseToAnyPublisher()
    }

    private let feature: RootFeature
    private let subject: CurrentValueSubject<RootFeature.State, Never>

    init(initialState state: RootFeature.State, feature: @escaping () -> RootFeature) {
        self.state = state
        self.subject = CurrentValueSubject(state)
        self.feature = feature()
    }

    func apply(_ reduce: (RootFeature, inout RootFeature.State) -> Never?) {
        var state = state
        _ = reduce(feature, &state)
        self.state = state
    }

    func apply(
        _ apply: @escaping (RootFeature, RootFeature.State) async -> ((inout RootFeature.State) -> Never?)?
    ) -> Task<Void, Never> {
        Task { @MainActor in
            let mutation = await apply(self.feature, self.state)
            _ = mutation?(&self.state)
        }
    }
}
