import SwiftUI

// MARK: - Screen

/// Every POS session the company has recorded, newest first — the owner-side
/// mirror of the till's Session list.
///
/// Strictly read-only: a session is opened, counted and closed on the register
/// that owns the drawer. This screen renders /History and /Summary and offers
/// no action that could move a session between states.
struct PosSessionsView: View {
    @Bindable var auth: AuthManager

    @State private var vm = PosSessionsViewModel()
    @State private var searchText = ""
    @State private var filter: SessionFilter = .all
    @State private var registerFilter: String? = nil
    @State private var historyDepth: Int = 50
    @State private var selected: PosSessionDto? = nil

    @AppStorage("isDarkMode") private var isDarkMode = true

    var body: some View {
        NavigationStack {
            ZStack {
                SessionBackdrop(isDarkMode: isDarkMode)
                content
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search register, cashier or #id")
            .task { await reload() }
            .sheet(item: $selected) { session in
                PosSessionDetailView(session: session, vm: vm, auth: auth)
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }

    // MARK: Body pieces

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.sessions.isEmpty {
            ProgressView().controlSize(.large)
        } else if let error = vm.errorMessage, vm.sessions.isEmpty {
            ContentUnavailableView("Couldn't load sessions",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text(error))
        } else {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if !vm.liveSessions.isEmpty { liveStrip }
                    kpiGrid
                    filterBar
                    sessionList
                    footnote
                }
                .padding(.bottom, 30)
            }
            .refreshable { await refresh() }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("REGISTERS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary.opacity(0.6))
                Text("POS Sessions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            Spacer()

            headerMenu
            refreshControl
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var headerMenu: some View {
        Menu {
            Section("Register") {
                Button { registerFilter = nil } label: {
                    if registerFilter == nil {
                        Label("All registers", systemImage: "checkmark")
                    } else {
                        Text("All registers")
                    }
                }
                ForEach(vm.registerNames, id: \.self) { name in
                    Button { registerFilter = name } label: {
                        if registerFilter == name {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            }

            Section("History depth") {
                ForEach([25, 50, 100, 250], id: \.self) { depth in
                    Button {
                        historyDepth = depth
                        Task { await refresh() }
                    } label: {
                        if historyDepth == depth {
                            Label("Last \(depth)", systemImage: "checkmark")
                        } else {
                            Text("Last \(depth)")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                Text(registerFilter ?? "All")
                    .font(.footnote)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundColor(.primary)
        }
    }

    @ViewBuilder
    private var refreshControl: some View {
        if vm.isLoading {
            ProgressView()
                .controlSize(.small)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
        } else {
            Button {
                Task { await refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.footnote.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .foregroundColor(.primary)
            }
        }
    }

    private var liveStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SessionSectionLabel(text: "LIVE NOW", tint: .mint, showsPulse: true)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(vm.liveSessions) { session in
                        LiveSessionCard(session: session,
                                        summary: vm.summaries[session.id],
                                        cashier: vm.userLabel(session.openedByUserId))
                            .onTapGesture { selected = session }
                            .task { await loadSummary(session.id) }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
            }
        }
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                  spacing: 12) {
            SessionKpiTile(title: "Live now",
                           value: "\(vm.liveSessions.count)",
                           caption: vm.liveSessions.isEmpty ? "No register trading" : registerSubtitle,
                           icon: "dot.radiowaves.left.and.right",
                           tint: .mint)

            SessionKpiTile(title: "Sessions",
                           value: "\(vm.sessions.count)",
                           caption: "Last \(historyDepth) loaded",
                           icon: "square.stack.3d.up.fill",
                           tint: .teal)

            SessionKpiTile(title: "Cash variance",
                           value: SessionFormat.signedMoney(vm.netCashDifference),
                           caption: varianceCaption,
                           icon: "arrow.up.arrow.down",
                           tint: varianceTint)

            SessionKpiTile(title: "Needs attention",
                           value: "\(vm.flaggedCount)",
                           caption: vm.flaggedCount == 0 ? "All clean" : "Variance, force-close or late sales",
                           icon: "exclamationmark.triangle.fill",
                           tint: vm.flaggedCount == 0 ? .secondary : .orange)
        }
        .padding(.horizontal)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SessionFilter.allCases) { option in
                    Button {
                        withAnimation(.snappy) { filter = option }
                    } label: {
                        SessionFilterChip(title: option.title,
                                          icon: option.icon,
                                          count: count(for: option),
                                          isOn: filter == option,
                                          tint: option.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var sessionList: some View {
        if filteredSessions.isEmpty {
            ContentUnavailableView("No sessions match",
                                   systemImage: "line.3.horizontal.decrease.circle",
                                   description: Text("Try another register, filter or search term."))
                .padding(.top, 20)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(filteredSessions) { session in
                    SessionRow(session: session,
                               summary: vm.summaries[session.id],
                               cashier: vm.userLabel(session.openedByUserId))
                        .onTapGesture { selected = session }
                        .task { await loadSummary(session.id) }
                }
            }
            .padding(.horizontal)
        }
    }

    private var footnote: some View {
        Text("Read-only. Sessions are opened, counted and closed on the register.")
            .font(.caption2)
            .foregroundColor(.primary.opacity(0.45))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.top, 6)
    }

    // MARK: Derived state

    private var filteredSessions: [PosSessionDto] {
        var rows = vm.sessions

        if let registerFilter {
            rows = rows.filter { $0.registerName == registerFilter }
        }

        switch filter {
        case .all:       break
        case .live:      rows = rows.filter { $0.isLive }
        case .closed:    rows = rows.filter { !$0.isLive }
        case .attention: rows = rows.filter { $0.needsAttention }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return rows }

        return rows.filter { session in
            let haystack = [
                "#\(session.id)",
                session.registerName,
                session.state.title,
                session.statusName ?? "",
                vm.userLabel(session.openedByUserId),
                vm.userLabel(session.closedByUserId)
            ].joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(query)
        }
    }

    private func count(for option: SessionFilter) -> Int {
        switch option {
        case .all:       return vm.sessions.count
        case .live:      return vm.liveSessions.count
        case .closed:    return vm.sessions.filter { !$0.isLive }.count
        case .attention: return vm.flaggedCount
        }
    }

    private var registerSubtitle: String {
        let names = vm.liveSessions.map { $0.registerName }
        return names.joined(separator: ", ")
    }

    private var varianceTint: Color {
        if abs(vm.netCashDifference) < 0.005 { return .secondary }
        return vm.netCashDifference < 0 ? .red : .green
    }

    private var varianceCaption: String {
        if abs(vm.netCashDifference) < 0.005 { return "Drawers balanced" }
        return vm.netCashDifference < 0 ? "Short across the window" : "Over across the window"
    }

    // MARK: Loading

    private func reload() async {
        guard let token = auth.jwtToken else { return }
        await vm.load(apiBaseUrl: auth.apiBaseUrl, token: token, take: historyDepth)
    }

    private func refresh() async {
        guard let token = auth.jwtToken else { return }
        await vm.refresh(apiBaseUrl: auth.apiBaseUrl, token: token, take: historyDepth)
    }

    private func loadSummary(_ sessionId: Int) async {
        guard let token = auth.jwtToken else { return }
        await vm.loadSummary(for: sessionId, apiBaseUrl: auth.apiBaseUrl, token: token)
    }
}

// MARK: - Filters

enum SessionFilter: String, CaseIterable, Identifiable {
    case all
    case live
    case closed
    case attention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:       return "All"
        case .live:      return "Live"
        case .closed:    return "Closed"
        case .attention: return "Attention"
        }
    }

    var icon: String {
        switch self {
        case .all:       return "square.stack.3d.up.fill"
        case .live:      return "dot.radiowaves.left.and.right"
        case .closed:    return "checkmark.seal.fill"
        case .attention: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all:       return .teal
        case .live:      return .mint
        case .closed:    return .indigo
        case .attention: return .orange
        }
    }
}

// MARK: - Rows and cards

/// One line of the history list.
struct SessionRow: View {
    let session: PosSessionDto
    let summary: PosSessionSummaryDto?
    let cashier: String

    var body: some View {
        HStack(spacing: 14) {
            SessionStateGlyph(state: session.state)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.registerName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("#\(session.id)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary.opacity(0.45))
                    if session.forceClosed {
                        Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    if session.hasLateArrivals {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                Text(timeline)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.6))

                Text(cashier)
                    .font(.caption2)
                    .foregroundColor(.primary.opacity(0.45))
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 4) {
                if let summary {
                    Text(SessionFormat.money(summary.totalTaken))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(.primary)
                    Text("\(summary.orderCount) orders")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.5))
                } else {
                    Text(SessionFormat.money(0))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .redacted(reason: .placeholder)
                    Text("loading")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.35))
                }

                if session.hasCashDifference, let difference = session.cashDifference {
                    Text(SessionFormat.signedMoney(difference))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background((difference < 0 ? Color.red : Color.green).opacity(0.18),
                                    in: Capsule())
                        .foregroundColor(difference < 0 ? .red : .green)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundColor(.primary.opacity(0.3))
        }
        .padding(14)
        .glassCard()
        .contentShape(Rectangle())
    }

    private var timeline: String {
        let opened = SessionFormat.dateTime(session.openedAt)
        if let closedAt = session.closedAt {
            return "\(opened) → \(SessionFormat.time(closedAt)) · \(SessionFormat.duration(session.elapsed))"
        }
        return "\(opened) · open \(SessionFormat.duration(session.elapsed))"
    }
}

/// The hero card for a register that is trading right now.
struct LiveSessionCard: View {
    let session: PosSessionDto
    let summary: PosSessionSummaryDto?
    let cashier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SessionStatusPill(state: session.state)
                Spacer()
                Text("#\(session.id)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.registerName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("\(cashier) · open \(SessionFormat.duration(session.elapsed))")
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.6))
            }

            Divider().background(Color.primary.opacity(0.12))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TAKEN")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary.opacity(0.45))
                    Text(summary.map { SessionFormat.money($0.totalTaken) } ?? SessionFormat.money(0))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .redacted(reason: summary == nil ? .placeholder : [])
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("ORDERS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary.opacity(0.45))
                    Text(summary.map { "\($0.orderCount)" } ?? "0")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .redacted(reason: summary == nil ? .placeholder : [])
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.caption2)
                Text("Float \(SessionFormat.money(session.openingCash))")
                    .font(.caption2)
            }
            .foregroundColor(.primary.opacity(0.5))
        }
        .padding(16)
        .frame(width: 250, alignment: .leading)
        // Clipped to the same shape the glass card uses, otherwise the tint
        // paints square corners over the rounded material behind it.
        .background(
            LinearGradient(colors: [session.state.tint.opacity(0.22), .clear],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .glassCard(cornerRadius: 24)
        .contentShape(Rectangle())
    }
}

// MARK: - Small components

/// A four-up statistic tile.
struct SessionKpiTile: View {
    let title: String
    let value: String
    let caption: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(tint)
                Text(title.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary.opacity(0.55))
                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(caption)
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.45))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .glassCard(cornerRadius: 20)
    }
}

/// The rounded square that carries a session's state colour in the list.
struct SessionStateGlyph: View {
    let state: PosSessionState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(colors: [state.tint.opacity(0.45), state.tint.opacity(0.15)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
            Image(systemName: state.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(state.tint)
        }
        .frame(width: 44, height: 44)
    }
}

struct SessionStatusPill: View {
    let state: PosSessionState

    var body: some View {
        HStack(spacing: 5) {
            if state == .opened {
                PulsingDot(tint: state.tint)
            } else {
                Image(systemName: state.icon)
                    .font(.caption2.weight(.bold))
            }
            Text(state.badge)
                .font(.caption2)
                .fontWeight(.heavy)
                .kerning(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(state.tint.opacity(0.18), in: Capsule())
        .overlay(Capsule().stroke(state.tint.opacity(0.45), lineWidth: 1))
        .foregroundColor(state.tint)
    }
}

struct SessionFilterChip: View {
    let title: String
    let icon: String
    let count: Int
    let isOn: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
            Text(title)
                .font(.footnote)
                .fontWeight(.semibold)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .monospacedDigit()
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(isOn ? 0.15 : 0.08), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isOn ? AnyShapeStyle(tint.opacity(0.22)) : AnyShapeStyle(Material.ultraThinMaterial),
                    in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(isOn ? 0.55 : 0.0), lineWidth: 1))
        .foregroundColor(isOn ? tint : .primary.opacity(0.7))
    }
}

struct SessionSectionLabel: View {
    let text: String
    let tint: Color
    var showsPulse: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            if showsPulse { PulsingDot(tint: tint) }
            Text(text)
                .font(.caption)
                .fontWeight(.bold)
                .kerning(0.6)
                .foregroundColor(.primary.opacity(0.6))
            Spacer(minLength: 0)
        }
    }
}

/// The "still trading" beacon — a soft ring expanding out of a solid dot.
struct PulsingDot: View {
    var tint: Color = .mint
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.35))
                .scaleEffect(animate ? 1.7 : 0.7)
                .opacity(animate ? 0 : 0.9)
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
        }
        .frame(width: 16, height: 16)
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

/// Base layer for the session screens: the app's flat black/white ground with
/// two low-opacity pools of colour so the glass cards have something to
/// refract. Kept faint — no text contrast depends on them.
struct SessionBackdrop: View {
    let isDarkMode: Bool

    var body: some View {
        ZStack {
            (isDarkMode ? Color.black : Color.white)
            RadialGradient(colors: [Color.teal.opacity(isDarkMode ? 0.26 : 0.16), .clear],
                           center: .topLeading,
                           startRadius: 8,
                           endRadius: 420)
            RadialGradient(colors: [Color.indigo.opacity(isDarkMode ? 0.28 : 0.16), .clear],
                           center: .bottomTrailing,
                           startRadius: 8,
                           endRadius: 460)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card styling

struct SessionGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(SessionGlassCard(cornerRadius: cornerRadius))
    }
}
