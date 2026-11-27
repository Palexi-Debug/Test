import Foundation
import SwiftSoup

/// Portierung der Parser aus liblanis (Stundenplan, Vertretungsplan).
enum Parsers {
    // MARK: Hilfen

    static func vonBis(_ e: Element) -> (Int, Int)? {
        guard let raw = try? e.text() else { return nil }
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " - ")
        guard parts.count == 2 else { return nil }
        func mins(_ s: String) -> Int? {
            let p = s.split(separator: ":")
            guard p.count >= 2,
                  let h = Int(p[0].trimmingCharacters(in: .whitespaces)),
                  let m = Int(p[1].trimmingCharacters(in: .whitespaces)) else { return nil }
            return h * 60 + m
        }
        guard let a = mins(parts[0]), let b = mins(parts[1]) else { return nil }
        return (a, b)
    }

    static func text(_ e: Element?) -> String {
        guard let e = e, let t = try? e.text() else { return "" }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stripTags(_ s: String) -> String {
        let noTags = s.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
        let t = noTags.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (t == "-" || t == "---") ? "" : t
    }

    // MARK: Stundenplan

    static func timetable(html: String) throws -> Timetable {
        let doc = try SwiftSoup.parse(html)
        let badge = text(try doc.select("#aktuelleWoche").first())
        let weekDate = parseWeekDate(doc)
        guard let all = try doc.select("#all tbody").first() else {
            throw PortalError.parse("Stundenplan nicht gefunden")
        }
        let own = try doc.select("#own tbody").first()
        let allPlan = try roomPlan(all)
        var ownPlan: [[Lesson]]?
        if let own = own { ownPlan = try roomPlan(own) }
        let hourRows = try rows(all)
        return Timetable(all: allPlan, own: ownPlan, rows: hourRows,
                         weekBadge: badge, weekDate: weekDate)
    }

    /// "23.11.2026: Diese Woche ..." -> Montag der Woche (yyyy-MM-dd)
    static func parseWeekDate(_ doc: Document) -> String? {
        guard let body = doc.body(), let t = try? body.text() else { return nil }
        guard let re = try? NSRegularExpression(
            pattern: "(\\d{1,2})\\.(\\d{1,2})\\.(\\d{4})\\s*:\\s*Diese\\s+Woche",
            options: [.caseInsensitive]),
              let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              m.numberOfRanges == 4,
              let r1 = Range(m.range(at: 1), in: t), let r2 = Range(m.range(at: 2), in: t),
              let r3 = Range(m.range(at: 3), in: t),
              let d = Int(t[r1]), let mo = Int(t[r2]), let y = Int(t[r3]) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        guard let date = cal.date(from: DateComponents(year: y, month: mo, day: d)),
              let monday = cal.dateInterval(of: .weekOfYear, for: date)?.start else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: monday)
    }

    static func roomPlan(_ tbody: Element) throws -> [[Lesson]] {
        let rows = tbody.children().array()
        guard let first = rows.first else { return [] }
        let dayCount = first.children().size() - 1
        guard dayCount > 0 else { return [] }
        var result = Array(repeating: [Lesson](), count: dayCount)
        let slots: [(Int, Int)] = try tbody.select(".VonBis").array().compactMap { vonBis($0) }
        var parsed = Array(repeating: Array(repeating: false, count: dayCount), count: rows.count + 32)
        let offsetFirstRow = !text(first.children().array().first).isEmpty

        for (ri, row) in rows.enumerated() where ri > 0 {
            for (ci, col) in row.children().array().enumerated() where ci > 0 {
                let rowSpan = Int((try? col.attr("rowspan")) ?? "") ?? 1
                var day = ci - 1
                while day < dayCount && parsed[ri][day] { day += 1 }
                if day >= dayCount { continue }
                for i in 0..<max(rowSpan, 1) {
                    let r = ri + i
                    if r >= parsed.count { break }
                    parsed[r][day] = true
                }
                result[day] += try singleHour(col, y: ri, slots: slots, offsetFirstRow: offsetFirstRow, day: day)
            }
        }
        return result
    }

    static func rows(_ tbody: Element) throws -> [HourRow] {
        var out: [HourRow] = []
        for (ri, row) in tbody.children().array().enumerated() where ri > 0 {
            for col in row.children().array() {
                guard let e = try col.select(".VonBis").first(),
                      let labelRoot = try col.select(".print-show").first(),
                      let slot = vonBis(e) else { break }
                let label = text(try labelRoot.select("b").first() ?? labelRoot)
                out.append(HourRow(rowIndex: ri, label: label, startMin: slot.0, endMin: slot.1))
                break
            }
        }
        return out
    }

    static func singleHour(_ cell: Element, y: Int, slots: [(Int, Int)],
                           offsetFirstRow: Bool, day: Int) throws -> [Lesson] {
        var out: [Lesson] = []
        for row in try cell.select(".stunde").array() {
            let name = text(try row.select("b").first())
            let room = row.getChildNodes()
                .compactMap { ($0 as? TextNode)?.text().trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined()
            let teacher = text(try row.select("small").first())
            let badge = text(try row.select(".badge").first())
            let duration = max(Int((try? row.parent()?.attr("rowspan")) ?? "") ?? 1, 1)
            let startIndex = offsetFirstRow ? y : y - 1
            let endIndex = offsetFirstRow ? y + duration - 1 : y - 1 + duration - 1
            var start = 0, end = 0
            if !slots.isEmpty, startIndex >= 0, endIndex >= 0,
               startIndex < slots.count, endIndex < slots.count {
                start = slots[startIndex].0
                end = slots[endIndex].1
            }
            var id = (try? row.attr("data-mix")) ?? ""
            if id.isEmpty { id = "\(name)-\(room)" }
            out.append(Lesson(id: "\(id)-\(day)-\(start)", name: name, room: room, teacher: teacher,
                              badge: badge, startMin: start, endMin: end, row: y, duration: duration))
        }
        return out
    }

    // MARK: Vertretungsplan

    static func normalizeDate(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespaces)
        if t.range(of: "^\\d{2}\\.\\d{2}\\.\\d{4}$", options: .regularExpression) != nil { return t }
        if t.range(of: "^\\d{2}_\\d{2}_\\d{4}$", options: .regularExpression) != nil {
            return t.replacingOccurrences(of: "_", with: ".")
        }
        if t.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil {
            let p = t.split(separator: "-")
            return "\(p[2]).\(p[1]).\(p[0])"
        }
        return nil
    }

    static func substitutionDates(shell html: String) -> [String] {
        guard let doc = try? SwiftSoup.parse(html) else { return [] }
        var set = Set<String>()
        if let els = try? doc.select("[data-tag]") {
            for e in els.array() {
                if let raw = try? e.attr("data-tag"), let n = normalizeDate(raw) { set.insert(n) }
            }
        }
        if let els = try? doc.select("[id^=tag]") {
            for e in els.array() {
                let id = e.id()
                if id.range(of: "^tag\\d{2}_\\d{2}_\\d{4}$", options: .regularExpression) != nil,
                   let n = normalizeDate(String(id.dropFirst(3))) { set.insert(n) }
            }
        }
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return set.sorted { (f.date(from: $0) ?? .distantPast) < (f.date(from: $1) ?? .distantPast) }
    }

    /// true: Antwort ist nur eine Zahl (z. B. "-1" = Sitzung abgelaufen)
    static func isSentinel(_ body: String) -> Bool {
        let t = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && Double(t) != nil
    }

    static func hours(_ s: String) -> [Int] {
        let nums = s.matches(of: /\d+/).compactMap { Int($0.output) }
        guard let a = nums.first else { return [] }
        let b = nums.last ?? a
        return b >= a && b - a < 12 ? Array(a...b) : nums
    }

    static func substitutionsDay(body: String, date: String) throws -> [Substitution] {
        let t = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("<") { throw PortalError.parse("HTML statt Liste") }
        guard let data = t.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            throw PortalError.parse("kein JSON")
        }
        if obj is NSNumber { return [] }
        guard let arr = obj as? [[String: Any]] else { throw PortalError.parse("keine Liste") }
        return arr.map { e in
            func s(_ k: String) -> String {
                guard let v = e[k], !(v is NSNull) else { return "" }
                return stripTags("\(v)")
            }
            let h = s("Stunde")
            return Substitution(
                date: date, hours: hours(h), hoursText: h,
                fach: s("Fach"), fachAlt: s("Fach_alt"),
                vertreter: s("Vertreter").isEmpty ? s("Vertreterkuerzel") : s("Vertreter"),
                lehrer: s("Lehrer").isEmpty ? s("Lehrerkuerzel") : s("Lehrer"),
                raum: s("Raum"), raumAlt: s("Raum_alt"), klasse: s("Klasse"),
                art: s("Art"),
                hinweis: [s("Hinweis"), s("Hinweis2")].filter { !$0.isEmpty }.joined(separator: " · "))
        }
    }
}
