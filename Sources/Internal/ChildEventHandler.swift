// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation

/// The shape every scoped store uses to hand a child's event to its parent.
/// Mirrors the public `Store.ChildEventHandler`, with the parent feature as an explicit parameter.
typealias ChildEventHandler<ParentFeature: Feature, ChildFeature: Feature> = (
    _ childEvent: ChildFeature.Event,
    _ parentFeature: ParentFeature,
    _ parentState: inout ParentFeature.State
) -> ParentFeature.Event?
