import Domain
import Foundation
import Persistence

/// Reads the stores at export time and writes a file only on request. Nothing is cached, so deleted shots or sessions are
/// never exported (F17), and a cancelled export removes whatever it had written.
public struct ExportService: Sendable {
    private let sessions: any SessionRepository
    private let shots: any ShotRepository
    private let now: @Sendable () -> Date

    public init(sessions: any SessionRepository, shots: any ShotRepository, now: @escaping @Sendable () -> Date = { Date() }) {
        self.sessions = sessions
        self.shots = shots
        self.now = now
    }

    public func snapshot() async throws -> ExportSnapshot {
        let all = try await sessions.sessions()
        var collected: [Shot] = []
        for session in all {
            try Task.checkCancellation()
            try await collected.append(contentsOf: shots.shots(sessionID: session.id))
        }
        return ExportSnapshot(sessions: all, shots: collected)
    }

    public func data(_ format: ExportFormat, options: ExportOptions = ExportOptions()) async throws -> Data {
        let snap = try await snapshot()
        switch format {
        case .json: return try JSONExport.data(snap, options: options, now: now())
        case .csv: return Data(CSVExport.string(snap, options: options, now: now()).utf8)
        }
    }

    /// Writes into a fresh private temporary folder and returns the file. The caller shares it and then calls `discard`.
    /// If the task is cancelled at any point the folder is removed and `cancelled` is thrown.
    public func writeTemporary(
        _ format: ExportFormat,
        options: ExportOptions = ExportOptions(),
        under base: URL? = nil
    ) async throws -> URL {
        try await writeTemporary(format, options: options, under: base, afterWrite: nil)
    }

    /// `afterWrite` runs once the file exists and before the result is returned; tests use it to cancel at that exact moment.
    func writeTemporary(
        _ format: ExportFormat,
        options: ExportOptions,
        under base: URL?,
        afterWrite: (@Sendable () async -> Void)?
    ) async throws -> URL {
        let folder = (base ?? FileManager.default.temporaryDirectory).appendingPathComponent(
            "export-\(UUID().uuidString)",
            isDirectory: true
        )
        do {
            let payload = try await data(format, options: options)
            try Task.checkCancellation()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent("golflaunchr-export.\(format.fileExtension)")
            try payload.write(to: file, options: .atomic)
            await afterWrite?()
            try Task.checkCancellation()
            return file
        } catch {
            try? FileManager.default.removeItem(at: folder)
            if error is CancellationError {
                throw ExportError.cancelled
            }
            throw error
        }
    }

    /// Removes an export file and its private folder.
    public static func discard(_ file: URL) {
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }
}
