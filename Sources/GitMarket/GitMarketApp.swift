import GitMarketCore
import SwiftUI

@main
struct GitMarketApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            Image(systemName: model.updateCount > 0 ? "shippingbox.fill" : "shippingbox")
        }

        Window(AppIdentity.displayName, id: MainWindow.id) {
            MainWindowView(model: model)
        }
    }
}
