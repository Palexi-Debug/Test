import Foundation
import UIKit

/// Eigener Update-Kanal für iOS: Releases mit Tag "ios-N" (Vorabversion).
enum Updater {
    static var currentBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    @MainActor
    static func check() async -> String {
        guard let url = URL(string: "https://api.github.com/repos/Palexi-Debug/Test/releases?per_page=40") else {
            return "Update-Adresse ungültig."
        }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 20
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return "Update-Antwort nicht lesbar."
            }
            var best: (Int, String)?
            for r in list {
                guard let tag = r["tag_name"] as? String, tag.hasPrefix("ios-"),
                      let n = Int(tag.dropFirst(4)) else { continue }
                if best == nil || n > best!.0 { best = (n, (r["html_url"] as? String) ?? "") }
            }
            guard let b = best else { return "Noch kein iOS-Release gefunden." }
            if b.0 > currentBuild {
                if let u = URL(string: b.1) { await UIApplication.shared.open(u) }
                return "Neue Version (Build \(b.0)) verfügbar – Release-Seite geöffnet."
            }
            return "Du hast die neueste Version (Build \(currentBuild))."
        } catch {
            return "Update-Suche fehlgeschlagen: keine Verbindung."
        }
    }
}
