// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation
import os.log
import Combine

@MainActor
@dynamicMemberLookup
public final class Store<StoreFeature: Feature> {
    public typealias DeferredStateMutation = (inout StoreFeature.State) -> StoreFeature.Event?
    public typealias ChildEventHandler<ChildFeature: Feature> = (
        _ childEvent: ChildFeature.Event,
        _ parentFeature: StoreFeature,
        _ parentState: inout StoreFeature.State
    ) -> StoreFeature.Event?

    private let wrappedStore: any InternalStoring<StoreFeature>

    // NSMapTable is used instead of [AnyKeyPath: Weak<AnyObject>] because weak values are automatically
    // removed when the child store deallocates — avoiding stale key accumulation.
    // Key equality is pointer-based, which is correct here: Swift keypath literals are globally
    // deduplicated by the compiler, so `\Foo.child` produces the same pointer at every call site.
    private let scopeCache = NSMapTable<AnyKeyPath, AnyObject>(
        keyOptions: .strongMemory,
        valueOptions: .weakMemory
    )

    /// Creates a store with the given initial state for the given feature.
    public convenience init(
        state: StoreFeature.State,
        feature: @escaping () -> StoreFeature
    ) where StoreFeature.Event == Never {
        self.init(wrappedStore: RootStore(initialState: state, feature: feature))
    }

    init(wrappedStore: some InternalStoring<StoreFeature>) {
        self.wrappedStore = wrappedStore
    }

    /// Reads a value from the current state.
    public subscript<Value>(dynamicMember keyPath: KeyPath<StoreFeature.State, Value>) -> Value {
        wrappedStore.state[keyPath: keyPath]
    }

    /// Synchronously applies a mutation, propagating any returned event up to the parent store.
    @_disfavoredOverload
    public func apply(
        _ reduce: (StoreFeature, inout StoreFeature.State) -> StoreFeature.Event?
    ) {
        wrappedStore.apply(reduce)
    }

    /// Asynchronously performs work, then applies a mutation to the state.
    @discardableResult
    public func apply(
        _ apply: @escaping (StoreFeature, StoreFeature.State) async -> DeferredStateMutation?
    ) -> Task<Void, Never> {
        wrappedStore.apply(apply)
    }

    /// Returns a child store scoped to a sub-state of the current store, forwarding child events through the `onEvent` closure.
    /// - Note: The returned child store is cached by key path.
    public func scope<ChildFeature: Feature>(
        _ keyPath: WritableKeyPath<StoreFeature.State, ChildFeature.State>,
        feature: @escaping () -> ChildFeature,
        onEvent: @escaping ChildEventHandler<ChildFeature>
    ) -> Store<ChildFeature> where ChildFeature.State: Equatable {
        if let cached = scopeCache.object(forKey: keyPath) as? Store<ChildFeature> {
            return cached
        }

        let child = Store<ChildFeature>(
            wrappedStore: ScopedStore(
                parent: wrappedStore,
                keyPath: keyPath,
                feature: feature,
                onEvent: onEvent
            )
        )

        scopeCache.setObject(child, forKey: keyPath)

        return child
    }

    /// Returns a child store scoped to an optional sub-state, or nil if the sub-state is currently nil.
    /// Evicts any stale cache entry when returning nil.
    /// - Note: The returned child store is cached by key path.
    public func scope<ChildFeature: Feature>(
        _ keyPath: WritableKeyPath<StoreFeature.State, ChildFeature.State?>,
        feature: @escaping () -> ChildFeature,
        onEvent: @escaping ChildEventHandler<ChildFeature>
    ) -> Store<ChildFeature>? where ChildFeature.State: Equatable {
        guard let initialState = wrappedStore.state[keyPath: keyPath] else {
            scopeCache.removeObject(forKey: keyPath)
            return nil
        }

        if let cached = scopeCache.object(forKey: keyPath) as? Store<ChildFeature> {
            return cached
        }

        let child = Store<ChildFeature>(
            wrappedStore: OptionalScopedStore(
                parent: wrappedStore,
                keyPath: keyPath,
                initialState: initialState,
                feature: feature,
                onEvent: onEvent
            )
        )

        scopeCache.setObject(child, forKey: keyPath)

        return child
    }
    
    /// Returns a Combine publisher that emits the current value at `keyPath` and every subsequent change.
    public func publisher<Value: Equatable>(
        for keyPath: KeyPath<StoreFeature.State, Value>
    ) -> AnyPublisher<Value, Never> {
        wrappedStore.publisher
            .map { $0[keyPath: keyPath] }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
