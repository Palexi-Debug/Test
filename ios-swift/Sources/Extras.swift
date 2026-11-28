import Foundation
import SwiftSoup

// MARK: - Modelle: Kalender und Nachrichten

struct CalEvent: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var description: String
    var place: String
    var start: Date
    var end: Date
    var allDay: Bool
    var category: String
    var colorHex: String
}

struct MessageHeader: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var sender: String
    var date: String
    var unread: Bool
    var hidden: Bool
}

struct ChatMessage: Identifiable, Hashable {
    var id: String
    var date: String
    var author: String
    var own: Bool
    var text: String
}

struct Conversation {
    var parent: ChatMessage
    var replies: [ChatMessage]
    var noReply: Bool
}

// MARK: - Parser

enum ExtraParsers {
    static func unescape(_ s: String) -> String {
        (try? Entities.unescape(s)) ?? s
    }

    /// HTML-Text in lesbaren Text umwandeln (Zeilenumbrüche bleiben erhalten).
    static func plain(_ html: String) -> String {
        var t = html
        t = t.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
        t = t.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        t = unescape(t)
        t = t.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Name aus einem HTML-Schnipsel wie `<span><i class="fa fa-user"></i> Name</span>`.
    static func userName(_ s: String) -> String {
        guard s.contains("fa-user") || s.contains("</i>") else { return unescape(s) }
        if let r = s.range(of: "</i> ") {
            var rest = String(s[r.upperBound...])
            if let end = rest.range(of: "</span>") { rest = String(rest[..<end.lowerBound]) }
            return unescape(rest.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression))
                .trimmingCharacters(in: .whitespaces)
        }
        return plain(s)
    }

    // MARK: Kalender

    static func categories(html: String) -> [Int: (name: String, color: String)] {
        var out: [Int: (name: String, color: String)] = [:]
        guard let re = try? NSRegularExpression(pattern: "categories\\.push\\(\\s*(\\{[^}]+\\})\\s*\\)") else { return out }
        let ns = html as NSString
        for m in re.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            guard m.numberOfRanges > 1 else { continue }
            var obj = ns.substring(with: m.range(at: 1))
            obj = obj.replacingOccurrences(of: "(\\w+):", with: "\"$1\":", options: .regularExpression)
            obj = obj.replacingOccurrences(of: "'", with: "\"")
            guard let data = obj.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let idAny = json["id"]
            let id = (idAny as? Int) ?? Int("\(idAny ?? "")")
            guard let cid = id else { continue }
            out[cid] = (name: "\(json["name"] ?? "")", color: normalizeColor("\(json["color"] ?? "")"))
        }
        return out
    }

    static func normalizeColor(_ c: String) -> String {
        var h = c.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        let ok = h.count == 6 && h.allSatisfy { $0.isHexDigit }
        return ok ? h.uppercased() : "4242FC"
    }

    private static let formats: [DateFormatter] = {
        ["yyyy-MM-dd HH:mm:ss", "dd.MM.yyyy HH:mm:ss", "dd.MM.yyyy HH:mm", "yyyy-MM-dd"].map { f in
            let d = DateFormatter()
            d.dateFormat = f
            d.locale = Locale(identifier: "en_US_POSIX")
            d.timeZone = TimeZone(identifier: "Europe/Berlin")
            return d
        }
    }()

    static func parseDate(_ any: Any?) -> Date? {
        guard let any = any else { return nil }
        let raw = "\(any)".trimmingCharacters(in: .whitespaces)
        if raw.isEmpty || raw == "null" { return nil }
        for f in formats { if let d = f.date(from: raw) { return d } }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: raw)
    }

    static func events(json: String, categories: [Int: (name: String, color: String)]) throws -> [CalEvent] {
        guard let data = json.data(using: .utf8),
              let arr = try JSONSerialization.jsonObject(with: data) as? [Any] else {
            throw PortalError.parse("Kalender")
        }
        var out: [CalEvent] = []
        for case let item as [String: Any] in arr {
            guard let s = parseDate(item["Anfang"]) ?? parseDate(item["start"]),
                  let e = parseDate(item["Ende"]) ?? parseDate(item["end"]) else { continue }
            let cid = Int("\(item["category"] ?? "")")
            let cat = cid.flatMap { categories[$0] }
            let allDay = (item["allDay"] as? Bool) == true || "\(item["allDay"] ?? "")" == "true"
            out.append(CalEvent(
                id: "\(item["Id"] ?? UUID().uuidString)",
                title: plain("\(item["title"] ?? "")"),
                description: plain("\(item["description"] ?? "")"),
                place: plain("\(item["Ort"] ?? "")"),
                start: s, end: e, allDay: allDay,
                category: cat?.name ?? "",
                colorHex: cat?.color ?? "4242FC"))
        }
        return out.sorted { $0.start < $1.start }
    }

    // MARK: Nachrichten

    static func headers(json: String) throws -> [MessageHeader] {
        guard let data = json.data(using: .utf8),
              let arr = try JSONSerialization.jsonObject(with: data) as? [Any] else {
            throw PortalError.parse("Nachrichten")
        }
        var out: [MessageHeader] = []
        for case let e as [String: Any] in arr {
            let id = "\(e["Uniquid"] ?? "")"
            if id.isEmpty { continue }
            let unread = (e["unread"] as? Int) == 1 || "\(e["unread"] ?? "")" == "1"
            out.append(MessageHeader(
                id: id,
                title: unescape("\(e["Betreff"] ?? "")"),
                sender: userName("\(e["SenderName"] ?? "")"),
                date: "\(e["Datum"] ?? "")",
                unread: unread,
                hidden: "\(e["Papierkorb"] ?? "")" == "ja"))
        }
        return out
    }

    static func conversation(json: String) throws -> Conversation {
        guard let data = json.data(using: .utf8),
              let c = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PortalError.parse("Nachricht")
        }
        func msg(_ m: [String: Any]) -> ChatMessage {
            ChatMessage(id: "\(m["Uniquid"] ?? UUID().uuidString)",
                        date: unescape("\(m["Datum"] ?? "")"),
                        author: userName("\(m["username"] ?? "")"),
                        own: (m["own"] as? Bool) == true || "\(m["own"] ?? "")" == "1",
                        text: plain("\(m["Inhalt"] ?? "")"))
        }
        let replies = ((c["reply"] as? [Any]) ?? []).compactMap { $0 as? [String: Any] }.map(msg)
        return Conversation(parent: msg(c), replies: replies,
                            noReply: "\(c["noAnswerAllowed"] ?? "")" == "ja")
    }
}

// MARK: - Portal-Zugriffe

extension PortalClient {
    private static let ajaxHeaders = [
        "Accept": "*/*",
        "X-Requested-With": "XMLHttpRequest",
        "Sec-Fetch-Dest": "empty", "Sec-Fetch-Mode": "cors", "Sec-Fetch-Site": "same-origin",
    ]

    /// RSA-Handshake: erzeugt den Sitzungsschlüssel für verschlüsselte Nachrichten.
    func handshake() async throws {
        let k = try await send("https://start.schulportal.hessen.de/ajax.php?f=rsaPublicKey",
                               method: "POST", headers: Self.ajaxHeaders)
        guard let kd = k.body.data(using: .utf8),
              let kj = try? JSONSerialization.jsonObject(with: kd) as? [String: Any],
              let pem = kj["publickey"] as? String else { throw PortalError.parse("Schlüssel") }
        let pass = LanisCrypto.randomBytes(LanisCrypto.passphraseSize)
        guard let enc = LanisCrypto.rsaEncrypt(pass, pem: pem) else { throw PortalError.parse("RSA") }
        let h = try await send(
            "https://start.schulportal.hessen.de/ajax.php?f=rsaHandshake&s=\(Int.random(in: 0..<2000))",
            method: "POST", form: ["key": enc.base64EncodedString()], headers: Self.ajaxHeaders)
        guard let hd = h.body.data(using: .utf8),
              let hj = try? JSONSerialization.jsonObject(with: hd) as? [String: Any],
              let challenge = hj["challenge"] as? String,
              let back = LanisCrypto.decrypt(challenge, passphrase: pass),
              back == pass else { throw PortalError.parse("Handshake") }
        cryptoKey = pass
    }

    func messageHeaders() async throws -> [MessageHeader] {
        if cryptoKey == nil { try await handshake() }
        guard let key = cryptoKey else { throw PortalError.parse("Schlüssel") }
        let r = try await send("https://start.schulportal.hessen.de/nachrichten.php", method: "POST",
                               form: ["a": "headers", "getType": "All", "last": "0"],
                               headers: Self.ajaxHeaders)
        guard let d = r.body.data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let rows = j["rows"] as? String,
              let plain = LanisCrypto.decryptString(rows, passphrase: key) else {
            throw PortalError.parse("Nachrichten")
        }
        return try ExtraParsers.headers(json: plain)
    }

    func conversation(id: String) async throws -> Conversation {
        if cryptoKey == nil { try await handshake() }
        guard let key = cryptoKey,
              let encID = LanisCrypto.encryptString(id, passphrase: key) else {
            throw PortalError.parse("Schlüssel")
        }
        let r = try await send(
            "https://start.schulportal.hessen.de/nachrichten.php?a=read&msg=\(id)", method: "POST",
            form: ["a": "read", "uniqid": encID], headers: Self.ajaxHeaders)
        guard let d = r.body.data(using: .utf8),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let m = j["message"] as? String,
              let plain = LanisCrypto.decryptString(m, passphrase: key) else {
            throw PortalError.parse("Nachricht")
        }
        return try ExtraParsers.conversation(json: plain)
    }

    func calendar(from: Date, to: Date) async throws -> [CalEvent] {
        let page = try await send("https://start.schulportal.hessen.de/kalender.php")
        let cats = ExtraParsers.categories(html: page.body)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        let s = f.string(from: from), e = f.string(from: to)
        let r = try await send(
            "https://start.schulportal.hessen.de/kalender.php?f=getEvents&s=&start=\(s)&end=\(e)",
            method: "POST", form: ["f": "getEvents", "start": s, "end": e, "s": ""],
            headers: Self.ajaxHeaders)
        return try ExtraParsers.events(json: r.body, categories: cats)
    }
}
