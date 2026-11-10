import GitMarketCore
import SwiftUI

@main
struct GitMarketApp: App {
    var body: some Scene {
        MenuBarExtra(AppIdentity.displayName, systemImage: "shippingbox") {
            Button("Quit \(AppIdentity.displayName)") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
