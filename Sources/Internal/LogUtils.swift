// Copyright (c) 2026 Manuel Fernandez. All rights reserved.

import Foundation
import os.log

struct LogUtils {
    static func showLog(message: String, category: String? = nil) {
#if DEBUG
        os_log(
            .fault,
            dso: #dsohandle,
            log: OSLog(subsystem: "com.manolofdez.reducto", category: category ?? "Reducto"),
            "%@", message
        )
#endif
    }
}
