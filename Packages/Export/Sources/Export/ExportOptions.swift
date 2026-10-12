import Domain
import Foundation

/// What the person chose to include (spec F17). Defaults are the privacy-preserving ones.
public struct ExportOptions: Codable, Equatable, Sendable {
    /// Excluded shots are part of the history; they are exported with `included = false` so analysis can be reproduced.
    public var includeExcludedShots = true
    /// Demo/fixture shots never leave the app unless asked for (T13).
    public var includeSyntheticShots = false
    /// Diagnostic device identifiers (the device-profile version string) are omitted by default.
    public var includeDeviceIdentifiers = false
    /// Notes and media are never embedded in data exports; the flags record the choice made.
    public var includeNotes = false
    public var includeMedia = false

    public init() {}
}

public enum ExportFormat: String, Sendable, CaseIterable {
    case json, csv

    public var fileExtension: String {
        rawValue
    }
}

/// A point-in-time copy of what is stored. Built from the repositories on every export, so deleted data is never exported.
public struct ExportSnapshot: Sendable, Equatable {
    public let sessions: [Session]
    public let shots: [Shot]

    public init(sessions: [Session], shots: [Shot]) {
        self.sessions = sessions
        self.shots = shots
    }

    /// Applies the options: drops synthetic/excluded shots and sessions left without selected shots only if they were empty of them.
    func filtered(_ options: ExportOptions) -> ExportSnapshot {
        var kept = shots
        if !options.includeSyntheticShots {
            kept.removeAll(where: \.isSynthetic)
        }
        if !options.includeExcludedShots {
            kept.removeAll { !$0.included }
        }
        kept = kept.map { $0.sanitised(deviceIdentifier: options.includeDeviceIdentifiers, media: options.includeMedia) }
        let sessionIDs = Set(kept.map(\.sessionID))
        let hadShots = Set(shots.map(\.sessionID))
        // A session is kept if it still has shots, or never had any (an empty session is still the person's record).
        let keptSessions = sessions.filter { sessionIDs.contains($0.id) || !hadShots.contains($0.id) }
        return ExportSnapshot(sessions: keptSessions, shots: kept)
    }
}

extension Shot {
    static let omittedDeviceIdentifier = "omitted"

    /// A copy without the diagnostic device identifier and/or the media link, as the export options require.
    func sanitised(deviceIdentifier keepDevice: Bool, media keepMedia: Bool) -> Shot {
        if keepDevice, keepMedia {
            return self
        }
        let newVersions = keepDevice ? versions : ShotVersions(
            pipeline: versions.pipeline, flight: versions.flight, deviceProfile: Self.omittedDeviceIdentifier
        )
        return (try? Shot(
            id: id, sessionID: sessionID, sequence: sequence, mode: mode, swingHandedness: swingHandedness,
            clubSnapshot: clubSnapshot, calibrationID: calibrationID, impactTimeUTC: impactTimeUTC, metrics: metrics,
            environment: environment, versions: newVersions, included: included, mediaID: keepMedia ? mediaID : nil,
            isSynthetic: isSynthetic
        )) ?? self
    }
}
