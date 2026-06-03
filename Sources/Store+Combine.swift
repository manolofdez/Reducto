// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation
@preconcurrency import Combine

extension Store {
    /// Returns a Combine publisher that emits the current value at `keyPath` and every subsequent change.
    public func publisher<Value>(
        for keyPath: KeyPath<StoreFeature.State, Value>
    ) -> AnyPublisher<Value, Never> {
        let subject = CurrentValueSubject<Value, Never>(self[dynamicMember: keyPath])
        
        observeAndForward(keyPath: keyPath, into: subject)
        
        return subject.eraseToAnyPublisher()
    }

    private func observeAndForward<Value>(
        keyPath: KeyPath<StoreFeature.State, Value>,
        into subject: CurrentValueSubject<Value, Never>
    ) {
        withObservationTracking {
            _ = self[dynamicMember: keyPath]
        } onChange: { [weak self, weak subject] in
            Task { @MainActor [weak self, weak subject] in
                guard let self, let subject else { return }

                subject.send(self[dynamicMember: keyPath])

                self.observeAndForward(keyPath: keyPath, into: subject)
            }
        }
    }
}
