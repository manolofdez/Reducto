// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation

@MainActor
final class AsyncApplyToken {
    private(set) var isValid = true

    func invalidate() {
        isValid = false
    }
}
