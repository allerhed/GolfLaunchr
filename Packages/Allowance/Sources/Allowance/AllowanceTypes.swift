import Domain
import Foundation

/// Persisted device-local allowance state (F19). Holds no golf data. The reset time zone is fixed at activation: later language,
/// region or time-zone changes never reset usage or move the period.
public struct AllowanceState: Codable, Sendable, Equatable {
    public let activatedAt: Date
    public let timeZoneID: String
    /// The latest time ever seen on this device. The effective clock never goes behind it (clock-rollback safety).
    public private(set) var latestSeen: Date

    public init(activatedAt: Date, timeZoneID: String, latestSeen: Date) {
        self.activatedAt = activatedAt
        self.timeZoneID = timeZoneID
        self.latestSeen = max(latestSeen, activatedAt)
    }

    public mutating func observe(_ now: Date) {
        latestSeen = max(latestSeen, now)
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .gmt
    }
}

/// A subscription (or complimentary) entitlement as last verified by StoreKit. Valid offline for seven days after the last
/// verification, never past its known expiry, and not at all once revoked.
public struct Entitlement: Codable, Sendable, Equatable {
    public static let revalidationWindow: TimeInterval = 7 * 86400

    public let kind: AllowanceKind
    public let expiresAt: Date
    public let lastVerifiedAt: Date
    public let revoked: Bool

    public init(kind: AllowanceKind, expiresAt: Date, lastVerifiedAt: Date, revoked: Bool) {
        self.kind = kind
        self.expiresAt = expiresAt
        self.lastVerifiedAt = lastVerifiedAt
        self.revoked = revoked
    }

    public func isActive(now: Date) -> Bool {
        !revoked && now < expiresAt && now <= lastVerifiedAt.addingTimeInterval(Self.revalidationWindow)
    }
}

/// What arming a shot reserved. Settled exactly once when the shot commits, even if the period changes in between.
public struct Reservation: Codable, Sendable, Equatable {
    public let kind: AllowanceKind
    public let periodID: String?
    public let cost: Int
}

public enum ArmDecision: Equatable, Sendable {
    case allowed(Reservation)
    /// No allowance left. `nextReset` is the next free monthly grant, if there is one to show.
    case blocked(nextReset: Date?)
}

public struct AllowanceSnapshot: Equatable, Sendable {
    public let introRemaining: Int
    /// Credits left in the current month; 0 while the monthly grant is not yet unlocked.
    public let monthlyRemaining: Int
    public let monthlyPeriodID: String?
    public let nextReset: Date?
    public let isPro: Bool
}

public enum Feature: String, Sendable, CaseIterable {
    case basicPractice, history, voice, replay
    case dispersion, clubMapping, trends, targetDrill, ladderDrill, virtualGolf
}

public enum FeatureAccess: Equatable, Sendable {
    case allowed, requiresPro
}

/// Published prices (spec F19). Checkout amounts always come from StoreKit; these are for the saving statement and tests.
public enum Pricing {
    public static let monthlySEK = 49
    public static let annualSEK = 499
    public static var annualPerMonthSEK: Double {
        Double(annualSEK) / 12
    }

    /// Against twelve monthly payments, rounded to one decimal: 15.1.
    public static var annualSavingPercent: Double {
        let full = Double(monthlySEK * 12)
        return ((full - Double(annualSEK)) / full * 1000).rounded() / 10
    }

    /// The annual plan is cheaper from the eleventh paid month (11 x 49 = 539 > 499).
    public static var annualCheaperFromMonth: Int {
        (1 ... 12).first { $0 * monthlySEK > annualSEK } ?? 12
    }
}
