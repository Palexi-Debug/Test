import SwiftUI

// MARK: - Formatierung

private enum Fmt {
    static func make(_ f: String) -> DateFormatter {
        let d = DateFormatter()
        d.locale = Locale(identifier: "de_DE")
        d.dateFormat = f
        return d
    }
    static let day = make("EEEE, d. MMMM")
    static let time = make("HH:mm")
    static let key = make("dd.MM.yyyy")
    static func minutes(_ m: Int) -> String { String(format: "%d:%02d", m / 60, m % 60) }
}

private func color(hex: String) -> Color {
    let v = UInt32(hex, radix: 16) ?? 0x4242FC
    return Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                 blue: Double(v & 0xFF) / 255)
}

// MARK: - Heute

struct TodayView: View {
    @EnvironmentObject var model: AppModel
    @State private var showSettings = false

    private var weekdayIndex: Int { (Calendar.current.component(.weekday, from: Date()) + 5) % 7 }
    private var nowMin: Int {
        let c = Calendar.current
        return c.component(.hour, from: Date()) * 60 + c.component(.minute, from: Date())
    }

    private func lessons() -> [Lesson] {
        guard let t = model.snapshot.timetable else { return [] }
        let plan = t.own ?? t.all
        guard weekdayIndex < plan.count else { return [] }
        let w = t.weekBadge.uppercased()
        let letter = w.hasPrefix("G") ? "G" : (w.hasPrefix("U") ? "U" : "")
        return plan[weekdayIndex].filter { l in
            let b = l.badge.uppercased()
            guard b == "G" || b == "U" else { return true }
            return letter.isEmpty || letter == b
        }.sorted { $0.startMin < $1.startMin }
    }

    private func subsToday() -> [Substitution] {
        let key = Fmt.key.string(from: Date())
        return model.snapshot.substitutions.filter { $0.date == key }
    }

    private func upcomingEvents() -> [CalEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        return (model.snapshot.events ?? []).filter { $0.end >= start }.prefix(4).map { $0 }
    }

    @ViewBuilder
    private func highlight(_ ls: [Lesson]) -> some View {
        let current = ls.first { $0.startMin <= nowMin && nowMin < $0.endMin }
        let next = ls.first { $0.startMin > nowMin }
        if let l = current ?? next {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(current != nil ? "Jetzt" : "Als Nächstes").font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    if current != nil { NowBadge() }
                }
                Text(l.name).font(.title2.bold())
                Text([Fmt.minutes(l.startMin) + " – " + Fmt.minutes(l.endMin), l.room, l.teacher]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .foregroundColor(.secondary)
                if current != nil {
                    let total = max(l.endMin - l.startMin, 1)
                    ProgressView(value: Double(nowMin - l.startMin), total: Double(total))
                    Text("noch \(l.endMin - nowMin) Min.").font(.footnote).foregroundColor(.secondary)
                } else {
                    Text("in \(l.startMin - nowMin) Min.").font(.footnote).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassCard(tint: current != nil ? .green : nil, cornerRadius: 22)
        } else {
            Text("Heute ist der Unterricht vorbei.").foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16).glassCard(cornerRadius: 22)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusBanner(date: model.snapshot.timetableAt)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        Text(Fmt.day.string(from: Date())).font(.title3.bold())
                            .padding(.horizontal, 4)
                        let ls = lessons()
                        if ls.isEmpty {
                            Text(model.snapshot.timetable == nil ? "Noch keine Daten." : "Heute kein Unterricht.")
                                .foregroundColor(.secondary).padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading).glassCard()
                        } else {
                            highlight(ls)
                            Text("Heutige Stunden").font(.headline).padding(.horizontal, 4).padding(.top, 6)
                            ForEach(ls) { l in
                                let active = l.startMin <= nowMin && nowMin < l.endMin
                                HStack {
                                    Text(Fmt.minutes(l.startMin)).font(.caption.monospacedDigit())
                                        .frame(width: 44, alignment: .trailing)
                                    VStack(alignment: .leading) {
                                        Text(l.name).font(.headline)
                                        Text([l.room, l.teacher].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.subheadline).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(12).glassCard(tint: active ? .green : nil)
                            }
                        }
                        let subs = subsToday()
                        Text(subs.isEmpty ? "Keine Vertretung heute" : "Vertretungen heute (\(subs.count))")
                            .font(.headline).padding(.horizontal, 4).padding(.top, 6)
                        ForEach(subs) { s in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("Std. \(s.hoursText)").font(.headline)
                                    Text(s.fach.isEmpty ? s.fachAlt : s.fach)
                                    Spacer()
                                    Text(s.art).font(.caption.bold()).foregroundColor(s.isCancel ? .red : .orange)
                                }
                                Text([s.klasse, s.vertreter.isEmpty ? "" : "Vertr. \(s.vertreter)",
                                      s.raum.isEmpty ? "" : "Raum \(s.raum)"]
                                    .filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.subheadline).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12).glassCard(tint: s.isCancel ? .red : .orange)
                        }
                        let ev = upcomingEvents()
                        if !ev.isEmpty {
                            Text("Nächste Termine").font(.headline).padding(.horizontal, 4).padding(.top, 6)
                            ForEach(ev) { e in EventCard(event: e) }
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 16)
                }
                .refreshable { await model.refresh() }
            }
            .background(GlassBackdrop())
            .navigationTitle("Heute")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
}

// MARK: - Termine

struct EventCard: View {
    let event: CalEvent

    private var whenText: String {
        if event.allDay { return Fmt.day.string(from: event.start) + " · ganztägig" }
        let sameDay = Calendar.current.isDate(event.start, inSameDayAs: event.end)
        if sameDay {
            return Fmt.day.string(from: event.start) + " · " + Fmt.time.string(from: event.start)
                + " – " + Fmt.time.string(from: event.end)
        }
        return Fmt.day.string(from: event.start) + " bis " + Fmt.day.string(from: event.end)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(color(hex: event.colorHex)).frame(width: 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title).font(.headline)
                Text(whenText).font(.subheadline).foregroundColor(.secondary)
                if !event.place.isEmpty {
                    Label(event.place, systemImage: "mappin.and.ellipse")
                        .font(.footnote).foregroundColor(.secondary)
                }
                if !event.category.isEmpty {
                    Text(event.category).font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(color(hex: event.colorHex).opacity(0.25)))
                }
                if !event.description.isEmpty {
                    Text(event.description).font(.footnote).lineLimit(4)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard()
    }
}

struct EventsView: View {
    @EnvironmentObject var model: AppModel

    private var grouped: [(Date, [CalEvent])] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let upcoming = (model.snapshot.events ?? []).filter { $0.end >= start }
        let dict = Dictionary(grouping: upcoming) { cal.startOfDay(for: max($0.start, start)) }
        return dict.keys.sorted().map { ($0, dict[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusBanner(date: model.snapshot.eventsAt)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if grouped.isEmpty {
                            Text(model.loading ? "Lade …" : "Keine anstehenden Termine")
                                .foregroundColor(.secondary).padding(.top, 30)
                                .frame(maxWidth: .infinity)
                        }
                        ForEach(grouped, id: \.0) { day, items in
                            Text(Fmt.day.string(from: day)).font(.headline)
                                .padding(.horizontal, 4).padding(.top, 6)
                            ForEach(items) { e in EventCard(event: e) }
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 16)
                }
                .refreshable { await model.refresh() }
            }
            .background(GlassBackdrop())
            .navigationTitle("Termine")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
    }
}

// MARK: - Nachrichten

struct MessagesView: View {
    @EnvironmentObject var model: AppModel

    private var items: [MessageHeader] { (model.snapshot.messages ?? []).filter { !$0.hidden } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusBanner(date: model.snapshot.messagesAt)
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if items.isEmpty {
                            Text(model.loading ? "Lade …" : "Keine Nachrichten")
                                .foregroundColor(.secondary).padding(.top, 30)
                        }
                        ForEach(items) { m in
                            NavigationLink {
                                ConversationView(header: m)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Circle().fill(m.unread ? Color.accentColor : Color.clear)
                                        .frame(width: 10, height: 10).padding(.top, 6)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(m.title).font(m.unread ? .headline : .body)
                                            .foregroundColor(.primary).multilineTextAlignment(.leading)
                                        Text(m.sender).font(.subheadline).foregroundColor(.secondary)
                                        Text(m.date).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .glassCard(tint: m.unread ? .accentColor : nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 16)
                }
                .refreshable { await model.refresh() }
            }
            .background(GlassBackdrop())
            .navigationTitle("Nachrichten")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
    }
}

struct ConversationView: View {
    @EnvironmentObject var model: AppModel
    let header: MessageHeader
    @State private var conv: Conversation?
    @State private var error: String?

    private func bubble(_ m: ChatMessage) -> some View {
        VStack(alignment: m.own ? .trailing : .leading, spacing: 4) {
            HStack {
                Text(m.own ? "Du" : m.author).font(.caption.bold())
                Text(m.date).font(.caption).foregroundColor(.secondary)
            }
            Text(m.text).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: m.own ? .trailing : .leading)
        .padding(12)
        .glassCard(tint: m.own ? .accentColor : nil)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if let c = conv {
                    bubble(c.parent)
                    ForEach(c.replies) { r in bubble(r) }
                    if c.noReply {
                        Text("Auf diese Nachricht kann nicht geantwortet werden.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    Text("Antworten ist in der iOS-App noch nicht möglich.")
                        .font(.footnote).foregroundColor(.secondary)
                } else if let e = error {
                    Text(e).foregroundColor(.red).padding(.top, 30)
                    Button("Erneut versuchen") { Task { await load() } }
                } else {
                    ProgressView("Lade Nachricht …").padding(.top, 30)
                }
            }
            .padding(.horizontal).padding(.bottom, 16)
        }
        .background(GlassBackdrop())
        .navigationTitle(header.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        error = nil
        do { conv = try await model.loadConversation(header.id) }
        catch { self.error = error.localizedDescription }
    }
}
