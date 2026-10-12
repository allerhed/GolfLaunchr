import Domain
@testable import Export
import Foundation
import Persistence
import PersistenceTestSupport
import Testing

private let t0 = Date(timeIntervalSince1970: 1_791_716_400.123)

private let calibration: CalibrationRecord = {
    guard let c = try? CalibrationRecord(
        deviceProfileID: "x", format: CaptureFormatRecord(widthPx: 1, heightPx: 1, framesPerSecond: 240, lens: "w"),
        scaleMethod: .knownBallDiameter, metresPerPixel: 0.002, transform: [1, 0, 0, 0, 1, 0, 0, 0, 1], cameraDistanceM: 1,
        cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good, createdAt: t0, calibrationVersion: 1
    ) else { preconditionFailure("calibration") }
    return c
}()

private func newStore() async -> InMemoryStore {
    let store = InMemoryStore(allowsSynthetic: true)
    await store.save(calibration)
    return store
}

private func club(_ name: String) -> ClubSnapshot {
    guard let c = try? ClubSnapshot(id: UUID(), name: name, loftRad: 0.4) else { preconditionFailure("club") }
    return c
}

private func shot(
    _ session: Session, _ seq: Int, club: ClubSnapshot, carry: Double? = 130.123456789, lateral: Double? = -3.25,
    included: Bool = true, synthetic: Bool = false, media: UUID? = nil
) throws -> Shot {
    var m: [MetricKey: Domain.Measurement] = try [
        .ballSpeed: Domain.Measurement(key: .ballSpeed, value: 45.1, provenance: .measured, quality: .valid, uncertainty95: 0.4),
        .clubSpeed: Domain.Measurement.unavailable(.clubSpeed, failure: .blur),
    ]
    if let carry {
        m[.carry] = try Domain.Measurement(key: .carry, value: carry, provenance: .estimated, quality: .provisional)
    }
    if let lateral {
        m[.lateralLanding] = try Domain.Measurement(key: .lateralLanding, value: lateral, provenance: .estimated, quality: .provisional)
    }
    return try Shot(
        id: UUID(), sessionID: session.id, sequence: seq, mode: session.mode, swingHandedness: .left, clubSnapshot: club,
        calibrationID: calibration.id, impactTimeUTC: t0.addingTimeInterval(Double(seq)), metrics: m,
        environment: Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard),
        versions: ShotVersions(pipeline: "p1", flight: "f1", deviceProfile: "iPhone17,2-wide"), included: included, mediaID: media,
        isSynthetic: synthetic
    )
}

private func utf8(_ data: Data) -> String {
    String(bytes: data, encoding: .utf8) ?? ""
}

/// Minimal RFC 4180 reader used only to read our own output back.
private func parseCSV(_ text: String) -> [[String]] {
    var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
    let chars = Array(text)
    var i = 0
    while i < chars.count {
        let ch = chars[i]
        if quoted {
            if ch == "\"" {
                if i + 1 < chars.count, chars[i + 1] == "\"" {
                    field.append("\""); i += 1
                } else {
                    quoted = false
                }
            } else {
                field.append(ch)
            }
        } else if ch == "\"" {
            quoted = true
        } else if ch == "," {
            row.append(field); field = ""
        } else if ch == "\r\n" || ch == "\n" {
            row.append(field); field = ""; rows.append(row); row = []
        } else {
            field.append(ch)
        }
        i += 1
    }
    return rows
}

private struct World {
    let store: InMemoryStore
    let service: ExportService
    let sessions: [Session]
    let shots: [Shot]
}

private func world() async throws -> World {
    let store = await newStore()
    let a = try Session(mode: .practice, createdAt: t0, endedAt: t0.addingTimeInterval(600))
    let b = try Session(mode: .target, createdAt: t0.addingTimeInterval(86400))
    await store.save(a)
    await store.save(b)
    let seven = club("7 iron")
    let shots = try [
        shot(a, 1, club: seven), shot(a, 2, club: seven, carry: nil, lateral: nil), shot(a, 3, club: seven, included: false),
        shot(b, 1, club: club("PW"), synthetic: true)
    ]
    for s in shots {
        let ledger = try LedgerEntry(acceptedShotID: s.id, allowanceKind: .introductory, periodID: nil, creditCost: 1, committedAt: t0)
        _ = try await store.commitAccepted(s, ledger: ledger)
    }
    return World(store: store, service: ExportService(sessions: store, shots: store, now: { t0 }), sessions: [a, b], shots: shots)
}

struct JSONExportTests {
    @Test func roundTripPreservesEveryMeasurementAndNull() async throws {
        let w = try await world()
        let (service, shots) = (w.service, w.shots)
        var options = ExportOptions()
        options.includeSyntheticShots = true
        options.includeDeviceIdentifiers = true
        let doc = try await JSONExport.decode(service.data(.json, options: options))
        #expect(doc.schema == "golflaunchr-export/1" && doc.exportedAt == t0 && doc.shots.count == 4 && doc.sessions.count == 2)
        for original in shots {
            let back = try #require(doc.shots.first { $0.id == original.id })
            #expect(back == original) // every metric, provenance, quality, uncertainty, failure, flag
        }
        let noCarry = try #require(doc.shots.first { $0.metrics[.carry] == nil && $0.sequence == 2 })
        #expect(noCarry.value(.carry) == nil && noCarry.metrics[.clubSpeed]?.failure == .blur) // null stays null, never 0
        let carry = try #require(doc.shots.first { $0.sequence == 1 && !$0.isSynthetic }?.value(.carry))
        #expect(carry == 130.123456789) // exact bit pattern, not rounded
    }

    @Test func defaultsKeepPrivacyAndSyntheticOut() async throws {
        let service = try await world().service
        let doc = try await JSONExport.decode(service.data(.json))
        #expect(doc.shots.count == 3 && doc.shots.allSatisfy { !$0.isSynthetic })
        #expect(doc.shots.allSatisfy { $0.versions.deviceProfile == "omitted" && $0.mediaID == nil })
        #expect(doc.shots.contains { !$0.included }) // exclusion kept so analysis is reproducible
        #expect(doc.sessions.count == 1) // the demo-only session leaves with its demo shots
    }

    @Test func excludedShotsCanBeLeftOut() async throws {
        let service = try await world().service
        var o = ExportOptions()
        o.includeExcludedShots = false
        #expect(try await JSONExport.decode(service.data(.json, options: o)).shots.count == 2)
    }

    @Test func mediaLinkOnlyWhenAsked() async throws {
        let store = await newStore()
        let s = try Session(mode: .practice, createdAt: t0)
        await store.save(s)
        let withMedia = try shot(s, 1, club: club("7i"), media: UUID())
        let ledger = try LedgerEntry(
            acceptedShotID: withMedia.id,
            allowanceKind: .introductory,
            periodID: nil,
            creditCost: 1,
            committedAt: t0
        )
        _ = try await store.commitAccepted(withMedia, ledger: ledger)
        let service = ExportService(sessions: store, shots: store, now: { t0 })
        #expect(try await JSONExport.decode(service.data(.json)).shots.first?.mediaID == nil)
        var o = ExportOptions()
        o.includeMedia = true
        #expect(try await JSONExport.decode(service.data(.json, options: o)).shots.first?.mediaID == withMedia.mediaID)
    }

    @Test func unknownSchemaIsRejected() throws {
        let bad = Data(#"{"schema":"other/9","exportedAt":"2026-10-11T11:00:00.000Z","options":{},"sessions":[],"shots":[]}"#.utf8)
        #expect(throws: (any Error).self) { try JSONExport.decode(bad) }
    }

    @Test func outputIsDeterministic() async throws {
        let service = try await world().service
        #expect(try await service.data(.json) == service.data(.json))
    }
}

struct CSVExportTests {
    @Test func numbersRoundTripExactlyAndNullsAreEmpty() async throws {
        let service = try await world().service
        let rows = try await parseCSV(utf8(service.data(.csv)))
        let header = rows[0]
        #expect(rows.count == 4) // header + 3 non-synthetic shots
        #expect(rows.allSatisfy { $0.count == header.count })
        let col = { (name: String) -> Int in
            guard let i = header.firstIndex(of: name) else { preconditionFailure("no column \(name)") }
            return i
        }
        let first = rows[1]
        #expect(Double(first[col("carry_m")]) == 130.123456789)
        #expect(Double(first[col("lateralLanding_m")]) == -3.25) // negative numbers are numbers, not formulas
        #expect(first[col("carry_provenance")] == "estimated" && first[col("ballSpeed_uncertainty95")] == "0.4")
        let second = rows[2]
        #expect(second[col("carry_m")] == "" && second[col("carry_provenance")] == "") // never 0
        #expect(second[col("clubSpeed_mps")] == "")
        #expect(second[col("clubSpeed_failure")] == "blur" && second[col("clubSpeed_provenance")] == "unavailable")
        #expect(rows[3][col("included")] == "false")
        #expect(!header.contains("device_profile"))
    }

    @Test func formulaLeadingTextIsNeutralisedAndQuotingIsCorrect() {
        #expect(CSVExport.escape("=HYPERLINK(\"x\")") == "\"'=HYPERLINK(\"\"x\"\")\"")
        #expect(CSVExport.escape("+1") == "'+1" && CSVExport.escape("-2") == "'-2" && CSVExport.escape("@SUM") == "'@SUM")
        #expect(CSVExport.escape("\tcmd") == "'\tcmd" && CSVExport.escape("\rx") == "\"'\rx\"")
        #expect(CSVExport.escape("7 iron") == "7 iron" && CSVExport.escape("a,b") == "\"a,b\"" && CSVExport
            .escape("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSVExport.escape("line1\nline2") == "\"line1\nline2\"")
        #expect(CSVExport.escape("Järn 7, \"bästa\"") == "\"Järn 7, \"\"bästa\"\"\"") // Swedish text survives
    }

    @Test func aMaliciousClubNameCannotStartAFormulaInTheFile() async throws {
        let store = await newStore()
        let s = try Session(mode: .practice, createdAt: t0)
        await store.save(s)
        let evil = try shot(s, 1, club: club("=cmd|' /C calc'!A0"))
        let ledger = try LedgerEntry(acceptedShotID: evil.id, allowanceKind: .introductory, periodID: nil, creditCost: 1, committedAt: t0)
        _ = try await store.commitAccepted(evil, ledger: ledger)
        let csv = try await utf8(ExportService(sessions: store, shots: store).data(.csv))
        let rows = parseCSV(csv)
        let name = rows[1][rows[0].firstIndex(of: "club_name") ?? 0]
        #expect(name.hasPrefix("'=")) // a spreadsheet shows text, not a formula
        for cell in rows.dropFirst().flatMap(\.self) where cell.hasPrefix("=") {
            Issue.record("cell starts with =: \(cell)")
        }
    }

    @Test func decimalSeparatorNeverDependsOnLocale() {
        #expect(CSVExport.number(1234.5) == "1234.5" && CSVExport.number(nil) == "" && CSVExport.number(.nan) == "")
    }

    @Test func deviceIdentifierColumnOnlyWhenOptedIn() async throws {
        let service = try await world().service
        var o = ExportOptions()
        o.includeDeviceIdentifiers = true
        let rows = try await parseCSV(utf8(service.data(.csv, options: o)))
        #expect(rows[0].contains("device_profile") && rows[1][rows[0].firstIndex(of: "device_profile") ?? 0] == "iPhone17,2-wide")
    }
}

struct ExportServiceTests {
    @Test func deletedDataIsNeverExported() async throws {
        let w = try await world()
        let (store, service, sessions, shots) = (w.store, w.service, w.sessions, w.shots)
        try await store.deleteShot(id: shots[0].id)
        try await store.deleteSession(id: sessions[1].id)
        let doc = try await JSONExport.decode(service.data(.json))
        #expect(!doc.shots.contains { $0.id == shots[0].id } && doc.shots.count == 2 && doc.sessions.map(\.id) == [sessions[0].id])
        #expect(try await !utf8(service.data(.csv)).contains(shots[0].id.uuidString))
    }

    @Test func writesAFileThatCanBeDiscarded() async throws {
        let service = try await world().service
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("exp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = try await service.writeTemporary(.csv, under: base)
        #expect(FileManager.default.fileExists(atPath: file.path) && file.pathExtension == "csv")
        ExportService.discard(file)
        #expect(try FileManager.default.contentsOfDirectory(atPath: base.path).isEmpty) // nothing left behind
    }

    @Test func cancellationLeavesNoTemporaryFiles() async throws {
        let service = try await world().service
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("exp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let task = Task { () -> URL in
            try await Task.sleep(for: .milliseconds(50)) // cancelled while "preparing"
            return try await service.writeTemporary(.json, under: base)
        }
        task.cancel()
        await #expect(throws: (any Error).self) { try await task.value }
        #expect(try FileManager.default.contentsOfDirectory(atPath: base.path).isEmpty)
    }

    /// Cancelled after the file exists: the folder and file must be gone (the earlier tests cancel before anything is written).
    @Test func cancellationAfterTheFileIsWrittenRemovesIt() async throws {
        let service = try await world().service
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("exp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let seen = Seen()
        let task = Task { () -> URL in
            try await service.writeTemporary(.json, options: ExportOptions(), under: base) {
                await seen.record(((try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? []).count)
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        await #expect(throws: ExportError.cancelled) { try await task.value }
        #expect(await seen.count == 1, "the export folder existed at the moment of cancellation")
        #expect(try FileManager.default.contentsOfDirectory(atPath: base.path).isEmpty)
    }
}

private actor Seen {
    var count = -1
    func record(_ n: Int) {
        count = n
    }
}
