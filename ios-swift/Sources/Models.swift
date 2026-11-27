import Foundation

struct Lesson: Codable, Hashable {
    var id: String
    var name: String
    var room: String
    var teacher: String
    var badge: String
    var startMin: Int
    var endMin: Int
    var row: Int
    var duration: Int
    var cancelled: Bool = false
    var substituted: Bool = false
    var note: String = ""
}

struct HourRow: Codable, Hashable {
    var rowIndex: Int
    var label: String
    var startMin: Int
    var endMin: Int
}

struct Timetable: Codable {
    var plan: [[Lesson]]
    var rows: [HourRow]
    var weekBadge: String
    var weekDate: String?   // Montag der angezeigten Woche (yyyy-MM-dd)
}

struct Substitution: Codable, Hashable {
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
