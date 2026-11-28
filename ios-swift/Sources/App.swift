import SwiftUI

@main
struct SchulportalApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var lock = AppLock()
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
            .environmentObject(lock)
            .overlay {
                if lock.locked, model.creds != nil {
                    LockView().environmentObject(lock)
                }
            }
            .onChange(of: phase) { p in
                if p == .background { lock.didEnterBackground() }
                if p == .active {
                    lock.didBecomeActive()
                    if model.creds != nil { Task { await model.refresh() } }
                }
            }
        }
    }
}
