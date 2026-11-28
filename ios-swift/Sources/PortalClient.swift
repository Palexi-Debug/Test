import Foundation

/// Einfacher Portal-Client (Login wie in liblanis): Cookies von Hand, keine
/// automatischen Weiterleitungen.
final class PortalClient: NSObject, URLSessionTaskDelegate {
    struct Response {
        var status: Int
        var body: String
        var location: String?
    }

    private var cookies: [String: String] = [:]
    /// Sitzungsschlüssel für verschlüsselte Nachrichten (nach dem RSA-Handshake).
    var cryptoKey: Data?
    private let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 SchulportalApp"

    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.httpCookieStorage = nil
        c.httpShouldSetCookies = false
        c.timeoutIntervalForRequest = 30
        c.timeoutIntervalForResource = 90
        return URLSession(configuration: c, delegate: self, delegateQueue: nil)
    }()

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)   // Weiterleitung selbst auswerten
    }

    private func encode(_ form: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let s = form.map { k, v in
            let ek = k.addingPercentEncoding(withAllowedCharacters: allowed) ?? k
            let ev = v.addingPercentEncoding(withAllowedCharacters: allowed) ?? v
            return "\(ek)=\(ev)"
        }.joined(separator: "&")
        return Data(s.utf8)
    }

    func send(_ urlString: String, method: String = "GET",
              form: [String: String]? = nil,
              headers: [String: String] = [:]) async throws -> Response {
        guard let url = URL(string: urlString) else { throw PortalError.parse("URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        if !cookies.isEmpty {
            req.setValue(cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; "),
                         forHTTPHeaderField: "Cookie")
        }
        if let form = form {
            req.httpBody = encode(form)
            req.setValue("application/x-www-form-urlencoded; charset=UTF-8",
                         forHTTPHeaderField: "Content-Type")
        }
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw PortalError.network
        }
        guard let http = resp as? HTTPURLResponse else { throw PortalError.network }

        var fields: [String: String] = [:]
        for (k, v) in http.allHeaderFields {
            if let ks = k as? String, let vs = v as? String {
                fields[ks] = ks.lowercased() == "set-cookie"
                    ? vs.replacingOccurrences(of: "HttpOnly=1", with: "HttpOnly") : vs
            }
        }
        for c in HTTPCookie.cookies(withResponseHeaderFields: fields, for: url) {
            if c.value.isEmpty || c.value == "deleted" {
                cookies.removeValue(forKey: c.name)
            } else {
                cookies[c.name] = c.value
            }
        }
        let body = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        return Response(status: http.statusCode, body: body,
                        location: http.value(forHTTPHeaderField: "Location"))
    }

    private func absolute(_ loc: String, base: String) -> String {
        if let u = URL(string: loc, relativeTo: URL(string: base)), u.scheme != nil {
            return u.absoluteString
        }
        return loc
    }

    func login(_ c: Credentials) async throws {
        cookies = [:]
        cryptoKey = nil
        let down = "Der Bereich der pädagogischen Organisation steht Ihnen aktuell nicht zur Verfügung."
        let r0 = try await send("https://start.schulportal.hessen.de/")
        if r0.status == 503 || r0.body.contains(down) { throw PortalError.down }

        cookies = [:]
        let r1 = try await send(
            "https://login.schulportal.hessen.de/?i=\(c.school)", method: "POST",
            form: ["user": "\(c.school).\(c.user)", "user2": c.user, "password": c.password])
        if r1.status == 503 { throw PortalError.down }
        guard r1.location != nil else {
            if r1.body.contains("authErrorLocktime") {
                let t = r1.body.components(separatedBy: "authErrorLocktime").dropFirst().first ?? ""
                let digits = t.prefix(80).filter { $0.isNumber }
                throw PortalError.locked(String(digits.prefix(4)))
            }
            throw PortalError.wrongCredentials
        }
        let r2 = try await send("https://connect.schulportal.hessen.de")
        guard let loc = r2.location, !loc.isEmpty else { throw PortalError.wrongCredentials }
        let loginURL = absolute(loc, base: "https://connect.schulportal.hessen.de")

        cookies = [:]
        _ = try await send(loginURL)
    }

    func timetableHTML() async throws -> String {
        let r1 = try await send("https://start.schulportal.hessen.de/stundenplan.php")
        if r1.body.contains("id=\"all\"") { return r1.body }
        if let loc = r1.location {
            let r2 = try await send(absolute(loc, base: "https://start.schulportal.hessen.de/"))
            return r2.body
        }
        return r1.body
    }

    func substitutionsHTML() async throws -> String {
        try await send("https://start.schulportal.hessen.de/vertretungsplan.php").body
    }

    func substitutionsDay(_ date: String) async throws -> String {
        try await send(
            "https://start.schulportal.hessen.de/vertretungsplan.php?a=my", method: "POST",
            form: ["tag": date, "ganzerPlan": "true"],
            headers: ["Accept": "*/*"]).body
    }
}
