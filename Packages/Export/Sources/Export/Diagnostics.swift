import Domain
import Foundation
import Persistence

/// Device and app facts the app supplies. No identifiers.
public struct DiagnosticsFacts: Sendable, Equatable {
    public var appVersion: String
    public var buildNumber: String
    public var osVersion: String
    public var deviceClass: String
    public var language: String
    public var storageFreeMegabytes: Int?

    public init(
        appVersion: String, buildNumber: String, osVersion: String, deviceClass: String, language: String, storageFreeMegabytes: Int?
    ) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.osVersion = osVersion
        self.deviceClass = deviceClass
        self.language = language
        self.storageFreeMegabytes = storageFreeMegabytes
    }
}

public struct DiagnosticsReport: Sendable, Equatable {
    public let sessionCount: Int
    public let shotCount: Int
    /// Failure code -> how many unavailable metrics carry it.
    public let failureCounts: [String: Int]
    /// Exactly what would be shared. The golfer sees this text before anything is shared.
    public let text: String
}

/// F21: a redacted support bundle. Versions, counts and failure codes only: never shot values, club names, ids, dates or media. Built on
/// request, never sent anywhere by the app; the golfer previews the text and chooses whether to share it.
public struct DiagnosticsService: Sendable {
    private let sessions: any SessionRepository
    private let shots: any ShotRepository

    public init(sessions: any SessionRepository, shots: any ShotRepository) {
        self.sessions = sessions
        self.shots = shots
    }

    public func report(facts: DiagnosticsFacts) async throws -> DiagnosticsReport {
        let all = try await sessions.sessions()
        var shotCount = 0
        var failures: [String: Int] = [:]
        var pipelines = Set<String>(), flights = Set<String>(), profiles = Set<String>()
        for session in all {
            for shot in try await shots.shots(sessionID: session.id) {
                shotCount += 1
                pipelines.insert(shot.versions.pipeline)
                flights.insert(shot.versions.flight)
                profiles.insert(shot.versions.deviceProfile)
                for measurement in shot.metrics.values {
                    if let failure = measurement.failure {
                        failures[failure.rawValue, default: 0] += 1
                    }
                }
            }
        }
        func list(_ set: Set<String>) -> String {
            set.isEmpty ? "none" : set.sorted().joined(separator: ", ")
        }
        let failureLines = failures.isEmpty ? ["Failure codes: none"] :
            ["Failure codes:"] + failures.sorted { $0.key < $1.key }.map { "  \($0.key): \($0.value)" }
        let lines = [
            "GolfLaunchr diagnostic bundle",
            "App: \(facts.appVersion) (\(facts.buildNumber))",
            "System: \(facts.osVersion)",
            "Device class: \(facts.deviceClass)",
            "Language: \(facts.language)",
            "Free storage: \(facts.storageFreeMegabytes.map { "\($0) MB" } ?? "unknown")",
            "Sessions: \(all.count)",
            "Shots: \(shotCount)",
            "Pipeline versions: \(list(pipelines))",
            "Flight model versions: \(list(flights))",
            "Device profiles: \(list(profiles))",
            "Frame drops: not recorded",
        ] + failureLines + ["No video, clips, shot values, club names or dates are included."]
        return DiagnosticsReport(
            sessionCount: all.count,
            shotCount: shotCount,
            failureCounts: failures,
            text: lines.joined(separator: "\n")
        )
    }
}
