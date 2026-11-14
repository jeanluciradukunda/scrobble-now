#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Links come from API responses, so only https is handed to the system: a `file:` or app-scheme URL in a reply
/// would otherwise open a local file or launch another app.
enum ExternalLink {
    static func canOpen(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && !(url.host ?? "").isEmpty
    }

    @MainActor
    static func open(_ url: URL) {
        guard canOpen(url) else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}
