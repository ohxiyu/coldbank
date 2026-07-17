import SwiftUI

@main
struct ColdSignerApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            AppRootView(model: model)
        }
    }
}
