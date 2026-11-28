import SwiftUI
import LocalAuthentication

/// App-Sperre mit Face ID / Touch ID / Gerätecode. Sperrt nach 30 s im Hintergrund.
@MainActor
final class AppLock: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published var locked: Bool
    private var backgroundedAt: Date?
    private static let key = "appLockEnabled"

    init() {
        let e = UserDefaults.standard.bool(forKey: Self.key)
        enabled = e
        locked = e
    }

    func didEnterBackground() { backgroundedAt = Date() }

    func didBecomeActive() {
        if enabled, !locked, let t = backgroundedAt, Date().timeIntervalSince(t) > 30 {
            locked = true
        }
        backgroundedAt = nil
    }

    private func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { return false }
        do {
            return try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    func unlock() async {
        guard locked else { return }
        if await authenticate(reason: "Schulportal entsperren") { locked = false }
    }

    /// Schaltet die Sperre ein oder aus (beides nur nach erfolgreicher Prüfung).
    /// Gibt `false` zurück, wenn das Gerät keinen Code hat oder abgebrochen wurde.
    func setEnabled(_ on: Bool) async -> Bool {
        let ok = await authenticate(reason: on ? "App-Sperre einschalten" : "App-Sperre ausschalten")
        guard ok else { return false }
        enabled = on
        UserDefaults.standard.set(on, forKey: Self.key)
        if !on { locked = false }
        return true
    }
}

struct LockView: View {
    @EnvironmentObject var lock: AppLock

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill").font(.system(size: 44))
                Text("Schulportal ist gesperrt").font(.headline)
                Button("Entsperren") { Task { await lock.unlock() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding(30)
            .glassCard(cornerRadius: 26)
        }
        .task { await lock.unlock() }
    }
}
