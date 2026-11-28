import Foundation
import Security

enum Keychain {
    private static let service = "de.palexi.schulportal"

    static func save(_ c: Credentials) {
        guard let data = try? JSONEncoder().encode(c) else { return }
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: "login"]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> Credentials? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: "login",
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    static func delete() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: "login"]
        SecItemDelete(q as CFDictionary)
    }
}

enum Cache {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("snapshot.json")
    }

    static func load() -> Snapshot {
        guard let d = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(Snapshot.self, from: d) else { return Snapshot() }
        return s
    }

    static func save(_ s: Snapshot) {
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: url, options: .atomic) }
    }

    static func clear() { try? FileManager.default.removeItem(at: url) }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var creds: Credentials?
    @Published var snapshot: Snapshot
    @Published var loading = false
    @Published var message: String?
    @Published var offline = false
    @Published var updateText: String?

    private let client = PortalClient()

    init() {
        creds = Keychain.load()
        snapshot = Cache.load()
        if creds != nil { Task { await refresh() } }
    }

    func login(_ c: Credentials) async -> String? {
        loading = true
        defer { loading = false }
        do {
            try await client.login(c)
        } catch {
            return error.localizedDescription
        }
        Keychain.save(c)
        creds = c
        await refresh()
        return nil
    }

    func logout() {
        Keychain.delete()
        Cache.clear()
        creds = nil
        snapshot = Snapshot()
        message = nil
    }

    func refresh() async {
        guard let c = creds, !loading else { return }
        loading = true
        defer { loading = false }
        var problems: [String] = []
        do {
            try await client.login(c)
            offline = false
        } catch PortalError.network {
            offline = true
            message = "Offline – gespeicherte Daten werden angezeigt."
            return
        } catch PortalError.down {
            offline = true
            message = "Schulportal gerade nicht erreichbar – gespeicherte Daten werden angezeigt."
            return
        } catch {
            message = error.localizedDescription
            return
        }

        do {
            let html = try await client.timetableHTML()
            snapshot.timetable = try Parsers.timetable(html: html)
            snapshot.timetableAt = Date()
        } catch { problems.append("Stundenplan: \(error.localizedDescription)") }

        do {
            snapshot.substitutions = try await loadSubstitutions(c)
            snapshot.substitutionsAt = Date()
        } catch { problems.append("Vertretungen: \(error.localizedDescription)") }

        do {
            let cal = Calendar.current
            let from = cal.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            let to = cal.date(byAdding: .day, value: 200, to: Date()) ?? Date()
            snapshot.events = try await client.calendar(from: from, to: to)
            snapshot.eventsAt = Date()
        } catch { problems.append("Termine: \(error.localizedDescription)") }

        do {
            snapshot.messages = try await client.messageHeaders()
            snapshot.messagesAt = Date()
        } catch { problems.append("Nachrichten: \(error.localizedDescription)") }

        Cache.save(snapshot)
        message = problems.isEmpty ? nil : problems.joined(separator: "\n")
    }

    /// Lädt eine ganze Unterhaltung (erneuert bei Bedarf die Sitzung).
    func loadConversation(_ id: String) async throws -> Conversation {
        do {
            return try await client.conversation(id: id)
        } catch {
            guard let c = creds else { throw error }
            try await client.login(c)
            return try await client.conversation(id: id)
        }
    }

    private func loadSubstitutions(_ c: Credentials, retry: Bool = true) async throws -> [Substitution] {
        let shell = try await client.substitutionsHTML()
        let dates = Parsers.substitutionDates(shell: shell)
        var all: [Substitution] = []
        var bodies: [(String, String)] = []
        for d in dates { bodies.append((d, try await client.substitutionsDay(d))) }
        if retry, !bodies.isEmpty, bodies.allSatisfy({ Parsers.isSentinel($0.1) }) {
            try await client.login(c)   // Sitzung abgelaufen: einmal neu anmelden
            return try await loadSubstitutions(c, retry: false)
        }
        for (d, b) in bodies { all += try Parsers.substitutionsDay(body: b, date: d) }
        return all
    }

    func checkForUpdate() async {
        updateText = await Updater.check()
    }
}
