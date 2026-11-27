import Foundation

struct Lesson: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var room: String
    var teacher: String
    var badge: String
    var startMin: Int
    var endMin: Int
    var row: Int
    var duration: Int
}

struct HourRow: Codable, Hashable {
    var rowIndex: Int
    var label: String
    var startMin: Int
    var endMin: Int
}

struct Timetable: Codable {
    var all: [[Lesson]]
    var own: [[Lesson]]?
    var rows: [HourRow]
    var weekBadge: String
    var weekDate: String?   // Montag der angezeigten Woche (yyyy-MM-dd)
}

struct Substitution: Codable, Hashable, Identifiable {
    var id: String { "\(date)-\(hoursText)-\(fach)-\(klasse)-\(raum)-\(vertreter)-\(art)" }
    var date: String        // dd.MM.yyyy
    var hours: [Int]
    var hoursText: String
    var fach: String
    var fachAlt: String
    var vertreter: String
    var lehrer: String
    var raum: String
    var raumAlt: String
    var klasse: String
    var art: String
    var hinweis: String

    /// Gleiche Erkennung wie in der Android-App.
    var isCancel: Bool {
        let t = [art, hinweis].joined(separator: " ").lowercased()
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
        return ["entf", "ausfall", "freisetz", "faellt aus", "faellt ersatzlos",
                "faellt weg", "unterrichtsfrei"].contains { t.contains($0) }
    }
}

struct Credentials: Codable {
    var school: String
    var user: String
    var password: String
}

struct Snapshot: Codable {
    var timetable: Timetable?
    var substitutions: [Substitution] = []
    var timetableAt: Date?
    var substitutionsAt: Date?
}

enum PortalError: LocalizedError {
    case wrongCredentials
    case locked(String)
    case down
    case parse(String)
    case network

    var errorDescription: String? {
        switch self {
        case .wrongCredentials: return "Benutzername oder Passwort falsch."
        case .locked(let t): return "Zu viele Fehlversuche. Bitte \(t) Sekunden warten."
        case .down: return "Das Schulportal ist gerade nicht erreichbar."
        case .parse(let m): return "Daten konnten nicht gelesen werden (\(m))."
        case .network: return "Keine Internetverbindung."
        }
    }
}
