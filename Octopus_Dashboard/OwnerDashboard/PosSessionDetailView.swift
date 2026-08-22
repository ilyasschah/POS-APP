import SwiftUI
import Charts

/// One session, end to end: who ran it, what it took, how the drawer
/// reconciled, and every flag the server raised against it.
///
/// Read-only. The figures come from /PosSession/Summary, which recomputes them
/// against the database on every call — so for a CLOSED session it can
/// legitimately disagree with the frozen figures on the session row itself.
/// Where it does, both are shown rather than one silently winning.
struct PosSessionDetailView: View {
    let session: PosSessionDto
    let vm: PosSessionsViewModel
    let auth: AuthManager

    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true

    private var summary: PosSessionSummaryDto? { vm.summaries[session.id] }

    var body: some View {
        NavigationStack {
            ZStack {
                SessionBackdrop(isDarkMode: isDarkMode)

                ScrollView {
                    VStack(spacing: 14) {
                        heroCard
                        ForEach(flags) { flag in
                            SessionFlagBanner(flag: flag)
                        }
                        takingsCard
                        cashCard
                        methodsCard
                        auditCard
                        footnote
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .refreshable { await loadSummary(force: true) }
            }
            .navigationTitle("Session #\(session.id)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadSummary(force: session.isLive) }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SessionStatusPill(state: session.state)
                Spacer()
                Text(session.statusName ?? session.state.title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .monospaced()
                    .foregroundColor(.primary.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.registerName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(session.state.explanation)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.primary.opacity(0.12))

            VStack(spacing: 10) {
                SessionFactRow(icon: "arrow.up.forward.circle.fill",
                               label: "Opened",
                               value: SessionFormat.fullDateTime(session.openedAt),
                               detail: vm.userLabel(session.openedByUserId),
                               tint: .mint)

                SessionFactRow(icon: "arrow.down.forward.circle.fill",
                               label: "Closed",
                               value: session.closedAt.map { SessionFormat.fullDateTime($0) } ?? "Still open",
                               detail: session.closedAt == nil ? "—" : vm.userLabel(session.closedByUserId),
                               tint: session.closedAt == nil ? .orange : .indigo)

                SessionFactRow(icon: "clock.fill",
                               label: session.isLive ? "Open for" : "Duration",
                               value: SessionFormat.duration(session.elapsed),
                               detail: "",
                               tint: .teal)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [session.state.tint.opacity(0.20), .clear],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Takings

    private var takingsCard: some View {
        SessionCard(title: "Takings", icon: "chart.bar.fill", tint: .teal) {
            if let summary {
                HStack(alignment: .top, spacing: 0) {
                    SessionStatColumn(title: "Total taken",
                                      value: SessionFormat.money(summary.totalTaken),
                                      caption: "All methods")
                    Divider().frame(height: 42).background(Color.primary.opacity(0.12))
                    SessionStatColumn(title: "Orders",
                                      value: "\(summary.orderCount)",
                                      caption: "Documents banked")
                    Divider().frame(height: 42).background(Color.primary.opacity(0.12))
                    SessionStatColumn(title: "Average",
                                      value: SessionFormat.money(averageSale(summary)),
                                      caption: "Per order")
                }
            } else {
                SessionLoadingLine()
            }
        }
    }

    // MARK: - Cash reconciliation

    private var cashCard: some View {
        SessionCard(title: "Cash reconciliation", icon: "banknote", tint: .green) {
            VStack(spacing: 10) {
                SessionMoneyRow(symbol: "",
                                label: "Opening float",
                                caption: "Counted at opening control",
                                value: SessionFormat.money(session.openingCash))

                if let summary {
                    SessionMoneyRow(symbol: "+",
                                    label: "Cash payments",
                                    caption: nil,
                                    value: SessionFormat.money(summary.cashPayments))
                    SessionMoneyRow(symbol: "+",
                                    label: "Cash in",
                                    caption: "Top-ups into the drawer",
                                    value: SessionFormat.money(summary.cashIn))
                    SessionMoneyRow(symbol: "−",
                                    label: "Cash out",
                                    caption: "Drops and pay-outs",
                                    value: SessionFormat.money(summary.cashOut))
                } else {
                    SessionLoadingLine()
                }

                Divider().background(Color.primary.opacity(0.12))

                SessionMoneyRow(symbol: "=",
                                label: "Expected cash",
                                caption: session.expectedCash == nil ? "Computed live" : "Frozen when counting started",
                                value: expectedCashText,
                                emphasis: true)

                SessionMoneyRow(symbol: "",
                                label: "Counted",
                                caption: session.actualEndingCash == nil ? "The drawer has not been counted yet" : "What the cashier signed off",
                                value: session.actualEndingCash.map { SessionFormat.money($0) } ?? "—",
                                emphasis: true)

                if let difference = session.cashDifference {
                    SessionMoneyRow(symbol: "",
                                    label: "Difference",
                                    caption: difference < -0.005 ? "Short" : (difference > 0.005 ? "Over" : "Balanced"),
                                    value: SessionFormat.signedMoney(difference),
                                    emphasis: true,
                                    tint: differenceTint(difference))
                }

                if let toleranceNote {
                    SessionNote(text: toleranceNote, icon: "shield.lefthalf.filled")
                }

                if let recomputedNote {
                    SessionNote(text: recomputedNote, icon: "arrow.triangle.2.circlepath")
                }
            }
        }
    }

    // MARK: - Payment methods

    @ViewBuilder
    private var methodsCard: some View {
        SessionCard(title: "Payment mix", icon: "creditcard.fill", tint: .indigo) {
            if let summary {
                if summary.methods.isEmpty {
                    Text("No payments were taken in this session.")
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.5))
                } else {
                    VStack(spacing: 14) {
                        if !chartMethods.isEmpty {
                            ZStack {
                                Chart(chartMethods) { method in
                                    SectorMark(
                                        angle: .value("Amount", method.expected),
                                        innerRadius: .ratio(0.64),
                                        angularInset: 1.6
                                    )
                                    .cornerRadius(5)
                                    .foregroundStyle(color(for: method))
                                }
                                .chartLegend(.hidden)
                                .frame(height: 168)

                                VStack(spacing: 1) {
                                    Text("TAKEN")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary.opacity(0.45))
                                    Text(SessionFormat.money(summary.totalTaken))
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(.primary)
                                }
                            }
                        }

                        VStack(spacing: 10) {
                            ForEach(summary.methods) { method in
                                methodRow(method, total: summary.totalTaken)
                                if method.id != summary.methods.last?.id {
                                    Divider().background(Color.primary.opacity(0.08))
                                }
                            }
                        }
                    }
                }
            } else {
                SessionLoadingLine()
            }
        }
    }

    @ViewBuilder
    private func methodRow(_ method: PosSessionMethodDto, total: Double) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color(for: method))
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(method.paymentTypeName ?? "Method #\(method.paymentTypeId)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(method.isCash ? "Cash — physically counted" : "Confirmed, not counted")
                    .font(.caption2)
                    .foregroundColor(.primary.opacity(0.45))
                if let counted = method.counted {
                    Text("Counted \(SessionFormat.money(counted))")
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.45))
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text(SessionFormat.money(method.expected))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(.primary)
                Text(share(method.expected, of: total))
                    .font(.caption2)
                    .foregroundColor(.primary.opacity(0.45))
                if let difference = method.difference, abs(difference) >= 0.005 {
                    Text(SessionFormat.signedMoney(difference))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(difference < 0 ? .red : .green)
                }
            }
        }
    }

    // MARK: - Audit

    private var auditCard: some View {
        SessionCard(title: "Audit trail", icon: "number", tint: .purple) {
            VStack(spacing: 8) {
                SessionKeyValueRow(key: "Session id", value: "#\(session.id)")
                SessionKeyValueRow(key: "Register", value: session.registerName)
                SessionKeyValueRow(key: "Register id", value: session.posDeviceId.map { "\($0)" } ?? "—")
                SessionKeyValueRow(key: "Device local id", value: session.localId ?? "—")
                SessionKeyValueRow(key: "Company id", value: "\(session.companyId)")
                SessionKeyValueRow(key: "Status", value: "\(session.status) · \(session.statusName ?? session.state.title)")
                SessionKeyValueRow(key: "Opened by", value: "\(vm.userLabel(session.openedByUserId)) (#\(session.openedByUserId))")
                if let closedBy = session.closedByUserId {
                    SessionKeyValueRow(key: "Closed by", value: "\(vm.userLabel(closedBy)) (#\(closedBy))")
                }
                if let forcedBy = session.forceClosedByUserId {
                    SessionKeyValueRow(key: "Force-closed by", value: "\(vm.userLabel(forcedBy)) (#\(forcedBy))")
                }
                SessionKeyValueRow(key: "Last modified", value: SessionFormat.fullDateTime(session.lastModified))
                if let summary {
                    SessionKeyValueRow(key: "Cash methods", value: summary.cashMethodsConfigured ? "Configured" : "Inferred")
                    SessionKeyValueRow(key: "Tolerance", value: SessionFormat.money(summary.maxCashDifference))
                }
            }
        }
    }

    private var footnote: some View {
        Text("Read-only. Opening, counting and closing all happen on the register that owns the drawer.")
            .font(.caption2)
            .foregroundColor(.primary.opacity(0.45))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    // MARK: - Flags

    private var flags: [SessionFlag] {
        var result: [SessionFlag] = []

        if session.forceClosed {
            let reason = (session.forceCloseReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(SessionFlag(
                icon: "bolt.trianglebadge.exclamationmark.fill",
                title: "Force-closed by \(vm.userLabel(session.forceClosedByUserId))",
                message: reason.isEmpty
                    ? "No reason recorded. A force-close never counts the drawer — it exists for a register nobody can reach."
                    : reason,
                tint: .red))
        }

        if session.hasLateArrivals {
            result.append(SessionFlag(
                icon: "clock.badge.exclamationmark",
                title: "Late sales arrived",
                message: "A sale reached the server after this session closed. It kept this session and a Z-report correction was raised — the closed figures were deliberately not rewritten.",
                tint: .orange))
        }

        if let note = session.closingNote,
           !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(SessionFlag(
                icon: "text.quote",
                title: "Closing note",
                message: note,
                tint: .indigo))
        }

        if let summary, !summary.cashMethodsConfigured {
            result.append(SessionFlag(
                icon: "questionmark.circle.fill",
                title: "Cash methods were inferred",
                message: "This company has no PosSession.CashPaymentTypeIds setting, so which methods come out of the drawer was guessed. That moves money between counted and merely confirmed.",
                tint: .yellow))
        }

        if session.state == .closingControl {
            result.append(SessionFlag(
                icon: "list.clipboard.fill",
                title: "Counting in progress",
                message: "Selling has already stopped. Totals are frozen while the drawer is counted, so no sale can land between the expected figure and the count.",
                tint: .blue))
        }

        if session.state == .openingControl {
            result.append(SessionFlag(
                icon: "hourglass",
                title: "Opening float not confirmed",
                message: "The register is claimed but not trading. Until the float is confirmed, every later expected-cash figure would be built on an unverified balance.",
                tint: .orange))
        }

        return result
    }

    // MARK: - Derived values

    private var expectedCashText: String {
        if let frozen = session.expectedCash { return SessionFormat.money(frozen) }
        if let summary { return SessionFormat.money(summary.expectedCash) }
        return "—"
    }

    /// Only shown when the live recomputation disagrees with what was frozen at
    /// close — which is exactly what late sales look like after the fact.
    private var recomputedNote: String? {
        guard let summary, let frozen = session.expectedCash else { return nil }
        guard abs(summary.expectedCash - frozen) >= 0.005 else { return nil }
        return "Recomputed now: \(SessionFormat.money(summary.expectedCash)). The frozen figure above is what the cashier was held to; the gap is money that reached the server after the count."
    }

    private var toleranceNote: String? {
        guard let summary else { return nil }
        let tolerance = SessionFormat.money(summary.maxCashDifference)
        guard let difference = session.cashDifference else {
            return "Tolerance ±\(tolerance) — beyond that, closing needs manager authorisation."
        }
        let within = abs(difference) <= summary.maxCashDifference
        return within
            ? "Within the ±\(tolerance) tolerance."
            : "Beyond the ±\(tolerance) tolerance — this close required manager authorisation."
    }

    private var chartMethods: [PosSessionMethodDto] {
        (summary?.methods ?? []).filter { $0.expected > 0 }
    }

    private func averageSale(_ summary: PosSessionSummaryDto) -> Double {
        guard summary.orderCount > 0 else { return 0 }
        return summary.totalTaken / Double(summary.orderCount)
    }

    private func share(_ value: Double, of total: Double) -> String {
        guard abs(total) > 0.005 else { return "—" }
        let percent = value / total * 100
        return String(format: "%.1f%%", percent)
    }

    private func differenceTint(_ difference: Double) -> Color {
        if abs(difference) < 0.005 { return .green }
        return difference < 0 ? .red : .orange
    }

    private func color(for method: PosSessionMethodDto) -> Color {
        let palette: [Color] = [.teal, .indigo, .orange, .pink, .purple, .mint, .blue, .cyan]
        let methods = summary?.methods ?? []
        let index = methods.firstIndex(where: { $0.paymentTypeId == method.paymentTypeId }) ?? 0
        return palette[index % palette.count]
    }

    private func loadSummary(force: Bool) async {
        guard let token = auth.jwtToken else { return }
        await vm.loadSummary(for: session.id,
                             apiBaseUrl: auth.apiBaseUrl,
                             token: token,
                             force: force)
    }
}

// MARK: - Detail components

struct SessionFlag: Identifiable {
    // The title is the identity: `flags` is recomputed on every body pass, and
    // a fresh UUID each time would make ForEach rebuild every banner.
    var id: String { title }

    let icon: String
    let title: String
    let message: String
    let tint: Color
}

struct SessionFlagBanner: View {
    let flag: SessionFlag

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: flag.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(flag.tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(flag.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(flag.message)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(flag.tint.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(flag.tint.opacity(0.35), lineWidth: 1)
        )
    }
}

/// A titled glass panel — the detail screen is a stack of these.
struct SessionCard<Content: View>: View {
    let title: String
    var icon: String? = nil
    var tint: Color = .teal
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(tint)
                }
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .kerning(0.5)
                    .foregroundColor(.primary.opacity(0.6))
                Spacer(minLength: 0)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct SessionFactRow: View {
    let icon: String
    let label: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundColor(tint)
                .frame(width: 18)

            Text(label)
                .font(.footnote)
                .foregroundColor(.primary.opacity(0.6))

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.45))
                }
            }
        }
    }
}

/// One line of the running cash arithmetic: a sign, a label, an amount.
struct SessionMoneyRow: View {
    let symbol: String
    let label: String
    var caption: String? = nil
    let value: String
    var emphasis: Bool = false
    var tint: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(symbol)
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(.primary.opacity(0.35))
                .frame(width: 12, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(emphasis ? .subheadline : .footnote)
                    .fontWeight(emphasis ? .semibold : .regular)
                    .foregroundColor(.primary.opacity(emphasis ? 1 : 0.75))
                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundColor(.primary.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 6)

            Text(value)
                .font(emphasis ? .system(size: 17, weight: .bold, design: .rounded) : .footnote)
                .monospacedDigit()
                .foregroundColor(tint ?? .primary)
        }
    }
}

struct SessionStatColumn: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.primary.opacity(0.45))
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SessionKeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key)
                .font(.caption)
                .foregroundColor(.primary.opacity(0.5))
            Spacer(minLength: 8)
            Text(value)
                .font(.caption)
                .monospaced()
                .multilineTextAlignment(.trailing)
                .foregroundColor(.primary.opacity(0.8))
                .textSelection(.enabled)
        }
    }
}

struct SessionNote: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.4))
            Text(text)
                .font(.caption2)
                .foregroundColor(.primary.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}

struct SessionLoadingLine: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("Reading the session figures…")
                .font(.caption)
                .foregroundColor(.primary.opacity(0.5))
            Spacer(minLength: 0)
        }
    }
}
