import Foundation
import SwiftUI

// MARK: - Wire models
//
// Mirrors Back-End/Web-POS.Api/Models/PosSessionDto.cs. ASP.NET Core's default
// System.Text.Json settings camelCase property names, so "OpenedAt" lands as
// "openedAt" — every field below is spelled exactly as it arrives.
//
// This screen is READ-ONLY by design: it renders /PosSession/History and
// /PosSession/Summary and never calls Open/Close/ForceClose. Session state
// belongs to the till that owns the drawer.

struct PosSessionDto: Codable, Identifiable, Hashable {
    let id: Int

    /// The device's own UUID for this session — the idempotency key an offline
    /// register re-pushes until it lands.
    let localId: String?

    let companyId: Int
    let posDeviceId: Int?
    let posDeviceName: String?
    let openedByUserId: Int
    let openedAt: Date
    let closedByUserId: Int?
    let closedAt: Date?
    let openingCash: Double

    /// Frozen when the session entered CLOSING_CONTROL — the figure the cashier
    /// was actually held to, not a live recomputation.
    let expectedCash: Double?

    /// What was physically counted in the drawer at close.
    let actualEndingCash: Double?
    let cashDifference: Double?
    let closingNote: String?
    let status: Int
    let statusName: String?
    let forceClosed: Bool
    let forceClosedByUserId: Int?
    let forceCloseReason: String?

    /// A sale reached the server after this session closed. It stayed on this
    /// session and a Z-report correction was raised instead of rewriting it.
    let hasLateArrivals: Bool

    let lastModified: Date
}

/// One payment method's row in the reconciliation.
struct PosSessionMethodDto: Codable, Identifiable, Hashable {
    var id: Int { paymentTypeId }

    let paymentTypeId: Int
    let paymentTypeName: String?

    /// Comes out of the cash drawer, so it is physically counted rather than
    /// merely confirmed.
    let isCash: Bool

    let expected: Double

    // /Summary computes expectations live and leaves these null; they are here
    // because the DTO carries them and a future counts endpoint would fill them.
    let counted: Double?
    let difference: Double?
}

/// Everything the closing screen computes server-side — recomputed on every
/// call, so for a CLOSED session it can legitimately disagree with the frozen
/// figures on the session itself. That disagreement is late sales.
struct PosSessionSummaryDto: Codable, Hashable {
    let sessionId: Int
    let status: Int
    let statusName: String?
    let openedAt: Date
    let openedByUserId: Int

    /// Documents banked, not PosOrders — checkout consumes the order row.
    let orderCount: Int

    let openingCash: Double
    let cashPayments: Double
    let cashIn: Double
    let cashOut: Double
    let expectedCash: Double

    /// Everything taken, all methods.
    let totalTaken: Double

    let methods: [PosSessionMethodDto]

    /// Above this, closing needs manager authorisation.
    let maxCashDifference: Double

    /// False when the company never set PosSession.CashPaymentTypeIds and the
    /// cash methods were INFERRED — worth saying out loud, because it moves
    /// money between "counted" and "confirmed".
    let cashMethodsConfigured: Bool
}

// MARK: - Lifecycle

/// Mirrors Api.Domain.PosSessionStatus. The values start at 10 and that is
/// load-bearing: attendance shifts share the Shift table and use 0/1, so
/// disjoint ranges make "1 = closed" and "11 = trading right now" impossible
/// to confuse.
enum PosSessionState: Int, CaseIterable, Hashable {
    case openingControl = 10
    case opened = 11
    case closingControl = 12
    case closed = 13
    case unknown = -1

    /// States in which the register still holds this session and may not open
    /// another — CLOSING_CONTROL included.
    var isLive: Bool {
        self == .openingControl || self == .opened || self == .closingControl
    }

    var title: String {
        switch self {
        case .openingControl: return "Opening control"
        case .opened:         return "Trading"
        case .closingControl: return "Counting drawer"
        case .closed:         return "Closed"
        case .unknown:        return "Unknown"
        }
    }

    var badge: String {
        switch self {
        case .openingControl: return "OPENING"
        case .opened:         return "LIVE"
        case .closingControl: return "COUNTING"
        case .closed:         return "CLOSED"
        case .unknown:        return "UNKNOWN"
        }
    }

    var icon: String {
        switch self {
        case .openingControl: return "hourglass"
        case .opened:         return "dot.radiowaves.left.and.right"
        case .closingControl: return "list.clipboard.fill"
        case .closed:         return "checkmark.seal.fill"
        case .unknown:        return "questionmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .openingControl: return .orange
        case .opened:         return .mint
        case .closingControl: return .blue
        case .closed:         return .secondary
        case .unknown:        return .gray
        }
    }

    /// What the register may actually do in this state.
    var explanation: String {
        switch self {
        case .openingControl:
            return "Claimed for the day, opening float not confirmed yet. No selling."
        case .opened:
            return "Trading. Sales, refunds and cash movements are allowed."
        case .closingControl:
            return "Totals are frozen and the drawer is being counted. No new sales."
        case .closed:
            return "Finalised. This session cannot be reopened."
        case .unknown:
            return "Unrecognised status code — the app and the API may be out of step."
        }
    }
}

extension PosSessionDto {
    var state: PosSessionState { PosSessionState(rawValue: status) ?? .unknown }

    var isLive: Bool { state.isLive }

    var registerName: String {
        if let name = posDeviceName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        if let deviceId = posDeviceId { return "Register #\(deviceId)" }
        return "Unknown register"
    }

    /// A live session has no end yet, so it is measured against now.
    var elapsed: TimeInterval { (closedAt ?? Date()).timeIntervalSince(openedAt) }

    /// Anything rounding can produce is not a real difference.
    var hasCashDifference: Bool { abs(cashDifference ?? 0) >= 0.005 }

    var needsAttention: Bool { forceClosed || hasLateArrivals || hasCashDifference }
}

// MARK: - Formatting

enum SessionFormat {
    /// Shared with the widget through the App Group; "DH" keeps the fallback
    /// identical to the dashboard's hardcoded suffix.
    static var currencySymbol: String {
        UserDefaults(suiteName: "group.com.futur3.ownerapp")?
            .string(forKey: "currencySymbol") ?? "DH"
    }

    static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func money(_ value: Double) -> String {
        let number = amountFormatter.string(from: NSNumber(value: value))
            ?? String(format: "%.2f", value)
        return "\(number) \(currencySymbol)"
    }

    /// "+12.00 DH" / "−12.00 DH" — a shortfall reads as a shortfall at a glance.
    static func signedMoney(_ value: Double) -> String {
        if value > 0.005 { return "+" + money(value) }
        if value < -0.005 { return "−" + money(abs(value)) }
        return money(0)
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    static func fullDateTime(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours >= 24 { return "\(hours / 24)d \(hours % 24)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - JSON

struct PosApiError: Error {
    let message: String
}

enum PosApi {
    /// A decoder that survives both date shapes this API emits.
    nonisolated static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = PosApi.parseServerDate(raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognised date: \(raw)")
            }
            return date
        }
        return decoder
    }

    /// EF reads DateTime back from SQL Server as Kind=Unspecified, so most
    /// values arrive with NO timezone suffix even though the server wrote them
    /// with DateTime.UtcNow — and .NET emits up to 7 fractional digits, which
    /// ISO8601DateFormatter refuses outright. Normalise both, then parse.
    nonisolated static func parseServerDate(_ raw: String) -> Date? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 19 else { return nil }

        // Peel the zone off first so the fractional trim below cannot eat it.
        var zone = ""
        if value.hasSuffix("Z") {
            zone = "Z"
            value.removeLast()
        } else {
            let offsetStart = value.index(value.endIndex, offsetBy: -6)
            let tail = value[offsetStart...]
            if tail.first == "+" || tail.first == "-" {
                zone = String(tail)
                value = String(value[..<offsetStart])
            }
        }

        if let dot = value.firstIndex(of: ".") {
            let fraction = value[value.index(after: dot)...].prefix(3)
            value = String(value[..<dot]) + "." + fraction
        }

        // No suffix at all means Kind=Unspecified, written by DateTime.UtcNow —
        // so it IS UTC, and saying so is what stops "opened 09:12" drifting by
        // the device's own offset.
        let normalised = value + (zone.isEmpty ? "Z" : zone)

        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: normalised) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: normalised)
    }
}
