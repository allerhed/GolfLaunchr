import Domain
import Foundation

/// The versioned JSON export. Shots use the shot contract v1.0 unchanged, so a round trip reproduces every measurement.
public struct ExportDocument: Codable, Equatable, Sendable {
    public static let schema = "golflaunchr-export/1"

    public let schema: String
    public let exportedAt: Date
    public let options: ExportOptions
    public let sessions: [Session]
    public let shots: [Shot]
}

public enum JSONExport {
    public static func data(_ snapshot: ExportSnapshot, options: ExportOptions, now: Date) throws -> Data {
        let filtered = snapshot.filtered(options)
        let doc = ExportDocument(
            schema: ExportDocument.schema, exportedAt: now, options: options,
            sessions: filtered.sessions.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) },
            shots: Self.ordered(filtered.shots)
        )
        let encoder = ContractJSON.encoder()
        encoder.outputFormatting.insert(.prettyPrinted)
        return try encoder.encode(doc)
    }

    public static func decode(_ data: Data) throws -> ExportDocument {
        let doc = try ContractJSON.decoder().decode(ExportDocument.self, from: data)
        guard doc.schema == ExportDocument.schema else { throw ExportError.unsupportedSchema(doc.schema) }
        return doc
    }

    static func ordered(_ shots: [Shot]) -> [Shot] {
        shots.sorted { ($0.impactTimeUTC, $0.sessionID.uuidString, $0.sequence) < ($1.impactTimeUTC, $1.sessionID.uuidString, $1.sequence) }
    }
}

public enum ExportError: Error, Equatable {
    case unsupportedSchema(String)
    case cancelled
}
