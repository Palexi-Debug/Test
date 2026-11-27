import SwiftUI

@main
struct SchulportalApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            Group {
                if model.creds == nil {
                    LoginView()
                } else {
                    RootView()
                }
            }
            .environmentObject(model)
            .onChange(of: phase) { p in
                if p == .active, model.creds != nil {
                    Task { await model.refresh() }
                }
            }
        }
    }
}
