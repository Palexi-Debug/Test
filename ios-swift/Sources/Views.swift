import SwiftUI

// MARK: - Liquid-Glass-Design

/// Transluzente Karte. Mit dem neuesten SDK (iOS 26) echtes Liquid Glass
/// (`glassEffect`), sonst Material mit feiner Lichtkante und weichem Schatten.
struct GlassCard: ViewModifier {
    var tint: Color?
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .background(shape.fill((tint ?? .clear).opacity(tint == nil ? 0 : 0.16)))
                .glassEffect(.regular, in: shape)
        } else {
            fallback(content, shape)
        }
        #else
        fallback(content, shape)
        #endif
    }

    private func fallback(_ content: Content, _ shape: RoundedRectangle) -> some View {
        content
            .background(shape.fill((tint ?? .clear).opacity(tint == nil ? 0 : 0.14)))
            .background(.ultraThinMaterial, in: shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 5)
    }
}

extension View {
    func glassCard(tint: Color? = nil, cornerRadius: CGFloat = 18) -> some View {
        modifier(GlassCard(tint: tint, cornerRadius: cornerRadius))
    }
}

/// Farbiger Hintergrund, damit das Glas etwas zum Durchscheinen hat.
struct GlassBackdrop: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [Color.accentColor.opacity(0.28), Color.purple.opacity(0.14), Color.clear],
                startPoint: .topLeading, endPoint: .bottom)
            Circle().fill(Color.accentColor.opacity(0.18)).frame(width: 280).blur(radius: 70)
                .offset(x: 140, y: -260)
        }
        .ignoresSafeArea()
    }
}

/// Schwebendes, pulsierendes Badge für die laufende Stunde.
struct NowBadge: View {
    @State private var pulse = false

    var body: some View {
        Text("JETZT")
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Color.green))
            .foregroundColor(.white)
            .scaleEffect(pulse ? 1.08 : 1.0)
            .shadow(color: .green.opacity(0.55), radius: pulse ? 9 : 3)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

// MARK: - Anmeldung

struct LoginView: View {
    @EnvironmentObject var model: AppModel
    @State private var school = "6110"
    @State private var user = ""
    @State private var password = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Schulportal Hessen") {
                    TextField("Schulnummer", text: $school).keyboardType(.numberPad)
                    TextField("Benutzername", text: $user)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Passwort", text: $password)
                }
                if let error { Text(error).foregroundColor(.red) }
                Section {
                    Button {
                        Task {
                            error = await model.login(Credentials(
                                school: school.trimmingCharacters(in: .whitespaces),
                                user: user.trimmingCharacters(in: .whitespaces),
                                password: password))
                        }
                    } label: {
                        HStack {
                            Text("Anmelden")
                            if model.loading { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(model.loading || school.isEmpty || user.isEmpty || password.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(GlassBackdrop())
            .navigationTitle("Anmelden")
        }
    }
}

// MARK: - Hauptansicht

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Heute", systemImage: "sun.max") }
            TimetableView()
                .tabItem { Label("Stundenplan", systemImage: "calendar") }
            SubstitutionsView()
                .tabItem { Label("Vertretungen", systemImage: "arrow.left.arrow.right") }
            MessagesView()
                .tabItem { Label("Nachrichten", systemImage: "bubble.left.and.bubble.right") }
            EventsView()
                .tabItem { Label("Termine", systemImage: "calendar.badge.clock") }
        }
    }
}

struct StatusBanner: View {
    @EnvironmentObject var model: AppModel
    var date: Date?

    var body: some View {
        if model.offline || model.message != nil {
            VStack(alignment: .leading, spacing: 2) {
                if let m = model.message { Text(m) }
                if model.offline, let d = date {
                    Text("Veraltet · Stand \(d.formatted(date: .omitted, time: .shortened))")
                }
            }
            .font(.footnote)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(tint: .orange, cornerRadius: 14)
            .padding(.horizontal)
            .padding(.top, 6)
        }
    }
}

// MARK: - Stundenplan

private let dayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
private let dayShort = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

enum LessonState { case normal, cancelled, changed(Substitution) }

struct TimetableView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var day = min(max(Calendar.current.component(.weekday, from: Date()) + 5, 0) % 7, 4)
    @State private var useOwn = true

    private var tt: Timetable? { model.snapshot.timetable }

    private func plan(_ t: Timetable) -> [[Lesson]] {
        useOwn ? (t.own ?? t.all) : t.all
    }

    private func monday(_ t: Timetable) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        if let s = t.weekDate, let d = f.date(from: s) { return d }
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private func visible(_ l: Lesson, _ t: Timetable) -> Bool {
        let b = l.badge.uppercased()
        let w = t.weekBadge.uppercased()
        guard b == "G" || b == "U" else { return true }
        let letter = w.hasPrefix("G") ? "G" : (w.hasPrefix("U") ? "U" : "")
        return letter.isEmpty || letter == b
    }

    private func hourNumbers(_ l: Lesson, _ t: Timetable) -> [Int] {
        t.rows.filter { $0.startMin < l.endMin && $0.endMin > l.startMin }
            .compactMap { Int($0.label.filter(\.isNumber)) }
    }

    private func state(_ l: Lesson, dayIndex: Int, _ t: Timetable) -> LessonState {
        let cal = Calendar.current
        guard let date = cal.date(byAdding: .day, value: dayIndex, to: monday(t)) else { return .normal }
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        let key = f.string(from: date)
        let hours = hourNumbers(l, t)
        let name = l.name.lowercased()
        for s in model.snapshot.substitutions where s.date == key {
            guard !Set(s.hours).isDisjoint(with: hours) else { continue }
            let subj = [s.fachAlt, s.fach].map { $0.lowercased() }
            guard subj.contains(name) || (!l.teacher.isEmpty && s.lehrer.lowercased() == l.teacher.lowercased()) else { continue }
            return s.isCancel ? .cancelled : .changed(s)
        }
        return .normal
    }

    private func isNow(_ l: Lesson, dayIndex: Int) -> Bool {
        let c = Calendar.current
        let wd = (c.component(.weekday, from: Date()) + 5) % 7
        let m = c.component(.hour, from: Date()) * 60 + c.component(.minute, from: Date())
        return wd == dayIndex && m >= l.startMin && m < l.endMin
    }

    private func cardTint(_ st: LessonState, now: Bool) -> Color? {
        switch st {
        case .cancelled: return .red
        case .changed: return .orange
        case .normal: return now ? .green : nil
        }
    }

    @ViewBuilder
    private func lessonRow(_ l: Lesson, dayIndex: Int, _ t: Timetable) -> some View {
        let st = state(l, dayIndex: dayIndex, t)
        let now = isNow(l, dayIndex: dayIndex)
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(timeString(l.startMin)).font(.caption.monospacedDigit())
                Text(timeString(l.endMin)).font(.caption2.monospacedDigit()).foregroundColor(.secondary)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(l.name).font(.headline).strikethrough(isCancelled(st))
                    if !l.badge.isEmpty {
                        Text(l.badge).font(.caption2.bold()).padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                    }
                }
                switch st {
                case .changed(let s):
                    Text([s.fach, s.vertreter.isEmpty ? "" : "Vertr. \(s.vertreter)", s.raum]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline).foregroundColor(.orange)
                default:
                    Text([l.room, l.teacher].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                if isCancelled(st) { Text("Entfällt").font(.caption.bold()).foregroundColor(.red) }
            }
            Spacer(minLength: 0)
            if now { NowBadge() }
        }
        .opacity(isCancelled(st) ? 0.6 : 1)
        .padding(12)
        .glassCard(tint: cardTint(st, now: now))
    }

    private func isCancelled(_ s: LessonState) -> Bool {
        if case .cancelled = s { return true }
        return false
    }

    private func timeString(_ m: Int) -> String { String(format: "%d:%02d", m / 60, m % 60) }

    private func lessons(_ t: Timetable, _ d: Int) -> [Lesson] {
        let p = plan(t)
        guard d < p.count else { return [] }
        return p[d].filter { visible($0, t) }.sorted { $0.startMin < $1.startMin }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusBanner(date: model.snapshot.timetableAt)
                if let t = tt {
                    let dayCount = min(max(plan(t).count, 5), 7)
                    if sizeClass == .regular {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(0..<dayCount, id: \.self) { d in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(dayNames[d]).font(.headline).padding(.horizontal, 4)
                                        ForEach(lessons(t, d)) { l in lessonRow(l, dayIndex: d, t) }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(width: 240)
                                }
                            }.padding()
                        }
                    } else {
                        Picker("Tag", selection: $day) {
                            ForEach(0..<dayCount, id: \.self) { Text(dayShort[$0]).tag($0) }
                        }
                        .pickerStyle(.segmented).padding(.horizontal).padding(.vertical, 8)
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                let ls = lessons(t, day)
                                if ls.isEmpty { Text("Keine Stunden").foregroundColor(.secondary).padding(.top, 30) }
                                ForEach(ls) { l in lessonRow(l, dayIndex: day, t) }
                            }
                            .padding(.horizontal).padding(.bottom, 16)
                        }
                    }
                } else {
                    Spacer()
                    if model.loading { ProgressView("Lade Stundenplan …") }
                    else { Text("Noch keine Daten.").foregroundColor(.secondary) }
                    Spacer()
                }
            }
            .background(GlassBackdrop())
            .navigationTitle(tt.map { $0.weekBadge.isEmpty ? "Stundenplan" : "Stundenplan · \($0.weekBadge)" } ?? "Stundenplan")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if tt?.own != nil {
                        Picker("Plan", selection: $useOwn) {
                            Text("Mein Plan").tag(true)
                            Text("Alle").tag(false)
                        }.pickerStyle(.menu)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await model.refresh() } } label: {
                        if model.loading { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                }
            }
            .refreshable { await model.refresh() }
        }
    }
}

// MARK: - Vertretungen

struct SubstitutionsView: View {
    @EnvironmentObject var model: AppModel

    private var grouped: [(String, [Substitution])] {
        var order: [String] = []
        var map: [String: [Substitution]] = [:]
        for s in model.snapshot.substitutions {
            if map[s.date] == nil { order.append(s.date) }
            map[s.date, default: []].append(s)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    /// Rot = Entfall, Blau = Raumwechsel, Orange = sonstige Änderung.
    private func substitutionTint(_ s: Substitution) -> Color {
        if s.isCancel { return .red }
        if s.art.lowercased().contains("raum") { return .blue }
        return .orange
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusBanner(date: model.snapshot.substitutionsAt)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if grouped.isEmpty {
                            Text(model.loading ? "Lade …" : "Keine Vertretungen")
                                .foregroundColor(.secondary).padding(.top, 30)
                                .frame(maxWidth: .infinity)
                        }
                        ForEach(grouped, id: \.0) { date, items in
                            Text(date).font(.headline).padding(.horizontal, 4).padding(.top, 6)
                            ForEach(items) { s in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("Std. \(s.hoursText)").font(.headline)
                                        Text(s.fach.isEmpty ? s.fachAlt : s.fach)
                                        Spacer()
                                        Text(s.art).font(.caption.bold())
                                            .foregroundColor(substitutionTint(s))
                                    }
                                    Text([s.klasse, s.vertreter.isEmpty ? "" : "Vertr. \(s.vertreter)",
                                          s.raum.isEmpty ? "" : "Raum \(s.raum)"]
                                        .filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.subheadline).foregroundColor(.secondary)
                                    if !s.hinweis.isEmpty { Text(s.hinweis).font(.footnote) }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .opacity(s.isCancel ? 0.7 : 1)
                                .padding(12)
                                .glassCard(tint: substitutionTint(s))
                            }
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 16)
                }
            }
            .background(GlassBackdrop())
            .navigationTitle("Vertretungen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .refreshable { await model.refresh() }
        }
    }
}

// MARK: - Einstellungen

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var lock: AppLock
    @Environment(\.dismiss) private var dismiss
    @State private var lockError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Konto") {
                    if let c = model.creds {
                        LabeledContent("Schule", value: c.school)
                        LabeledContent("Benutzer", value: c.user)
                    }
                    Button("Abmelden", role: .destructive) { model.logout() }
                }
                Section("Sicherheit") {
                    Toggle("App-Sperre (Face ID / Code)", isOn: Binding(
                        get: { lock.enabled },
                        set: { on in
                            Task {
                                let ok = await lock.setEnabled(on)
                                lockError = ok ? nil : "Die App-Sperre konnte nicht geändert werden. Ist am Gerät ein Code eingerichtet?"
                            }
                        }))
                    if let e = lockError { Text(e).font(.footnote).foregroundColor(.red) }
                }
                Section("App") {
                    LabeledContent("Build", value: "\(Updater.currentBuild)")
                    Button("Nach Updates suchen") { Task { await model.checkForUpdate() } }
                    if let t = model.updateText { Text(t).font(.footnote).foregroundColor(.secondary) }
                }
                Section {
                    Text("Eigene iOS-App (SwiftUI) – iPhone und iPad. Inoffizieller Open-Source-Client für die Philipp-Reis-Schule. Enthalten: Heute, Stundenplan, Vertretungen, Nachrichten (lesen), Termine, App-Sperre.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(GlassBackdrop())
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
