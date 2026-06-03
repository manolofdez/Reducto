// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation

protocol InternalStoring<StoreFeature>: AnyObject {
    associatedtype StoreFeature: Feature

    var state: StoreFeature.State { get set }

    func apply(_ reduce: (StoreFeature, inout StoreFeature.State) -> StoreFeature.Event?)

    func apply(
        _ apply: @escaping (StoreFeature, StoreFeature.State) async -> ((inout StoreFeature.State) -> StoreFeature.Event?)?
    ) -> Task<Void, Never>
}
