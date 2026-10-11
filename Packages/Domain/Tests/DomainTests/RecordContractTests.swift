@testable import Domain
import Foundation
import Testing

struct RecordContractTests {
    let decoder = ContractJSON.decoder()
    let encoder = ContractJSON.encoder()
    let t0 = Date(timeIntervalSince1970: 1_791_716_400)

    // MARK: Club

    @Test func snapshotIsAValueCopy() throws {
        var club = Club(name: "7 iron", category: .iron, loftRad: 0.5236, sortOrder: 6)
        let snap = try club.snapshot()
        club.name = "Seven"
        club.loftRad = 0.6
        club.loftRevision += 1
        #expect(snap.name == "7 iron")
        #expect(snap.loftRad == 0.5236)
        #expect(snap.id == club.id)
    }

    @Test func clubRoundTripKeepsNilOptionals() throws {
        let club = Club(name: "Driver", category: .driver)
        let again = try decoder.decode(Club.self, from: encoder.encode(club))
        #expect(again == club)
        #expect(again.loftRad == nil)
        #expect(again.archivedAt == nil)
    }

    @Test func archivedClubRoundTrip() throws {
        let club = Club(name: "Old", category: .wedge, brand: "B", model: "M", archivedAt: t0)
        #expect(try decoder.decode(Club.self, from: encoder.encode(club)) == club)
    }

    @Test func snapshotWritesNullLoftAndRejectsBadInput() throws {
        let snap = try ClubSnapshot(id: UUID(), name: "Putter", loftRad: nil)
        let json = try #require(try String(data: encoder.encode(snap), encoding: .utf8))
        #expect(json.contains("\"loftRad\":null"))
        #expect(throws: ContractError.invalidName) { try ClubSnapshot(id: UUID(), name: "  ", loftRad: nil) }
        #expect(throws: ContractError.nonFiniteValue("loftRad")) { try ClubSnapshot(id: UUID(), name: "x", loftRad: .nan) }
    }

    // MARK: Session

    @Test func sessionRoundTripAndDateOrder() throws {
        let snap = try ClubSnapshot(id: UUID(), name: "PW", loftRad: 0.8)
        let s = try Session(mode: .target, createdAt: t0, endedAt: t0.addingTimeInterval(60), clubSnapshots: [snap])
        #expect(try decoder.decode(Session.self, from: encoder.encode(s)) == s)
        #expect(throws: ContractError.invalidDateOrder) { try Session(mode: .practice, createdAt: t0, endedAt: t0.addingTimeInterval(-1)) }
    }

    @Test func openSessionRoundTripKeepsNilEnd() throws {
        let s = try Session(mode: .practice, createdAt: t0)
        let again = try decoder.decode(Session.self, from: encoder.encode(s))
        #expect(again.endedAt == nil)
        #expect(again.recoveryState == .active)
    }

    // MARK: Calibration

    func makeCalibration(scale: Double = 0.002, transform: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1]) throws -> CalibrationRecord {
        try CalibrationRecord(
            deviceProfileID: "fixture-only",
            format: CaptureFormatRecord(widthPx: 1920, heightPx: 1080, framesPerSecond: 240, lens: "wide"),
            scaleMethod: .knownBallDiameter, metresPerPixel: scale, transform: transform,
            cameraDistanceM: 0.75, cameraHeightM: 0.2, cameraHeadingRad: 0, quality: .good, createdAt: t0, calibrationVersion: 1
        )
    }

    @Test func calibrationRoundTrip() throws {
        let c = try makeCalibration()
        #expect(try decoder.decode(CalibrationRecord.self, from: encoder.encode(c)) == c)
    }

    @Test func calibrationRejectsBadGeometry() {
        #expect(throws: ContractError.invalidCalibration("metresPerPixel")) { try makeCalibration(scale: 0) }
        #expect(throws: ContractError.invalidCalibration("metresPerPixel")) { try makeCalibration(scale: .nan) }
        #expect(throws: ContractError.invalidCalibration("transform")) { try makeCalibration(transform: [1, 0, 0]) }
        #expect(throws: ContractError.invalidCalibration("transform")) {
            try makeCalibration(transform: [1, 0, 0, 0, 1, 0, 0, 0, .infinity])
        }
    }

    // MARK: Ledger

    @Test func ledgerEntryHoldsOnlyUsageIDs() throws {
        let shotID = UUID()
        let e = try LedgerEntry(acceptedShotID: shotID, allowanceKind: .introductory, periodID: nil, creditCost: 1, committedAt: t0)
        #expect(e.id == shotID)
        let json = try #require(try String(data: encoder.encode(e), encoding: .utf8))
        #expect(Set(["acceptedShotID", "allowanceKind", "periodID", "creditCost", "committedAt"]).isSuperset(of: topLevelKeys(json)))
        #expect(try decoder.decode(LedgerEntry.self, from: encoder.encode(e)) == e)
    }

    @Test func ledgerRejectsNegativeCostAndUnknownKind() throws {
        #expect(throws: ContractError.invalidCreditCost(-1)) {
            try LedgerEntry(acceptedShotID: UUID(), allowanceKind: .monthly, periodID: "2026-10", creditCost: -1, committedAt: t0)
        }
        let id = "11111111-1111-4111-8111-111111111111"
        let bad = Data(
            #"{"acceptedShotID":"\#(id)","allowanceKind":"free-for-all","creditCost":1,"committedAt":"2026-10-11T11:00:00Z"}"#.utf8
        )
        #expect(throws: DecodingError.self) { try decoder.decode(LedgerEntry.self, from: bad) }
    }

    func topLevelKeys(_ json: String) -> Set<String> {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else { return [] }
        return Set(obj.keys)
    }

    // MARK: Shot built in code

    @Test func shotBuiltInCodeRejectsBadSequenceAndRoundTrips() throws {
        let snap = try ClubSnapshot(id: UUID(), name: "6 iron", loftRad: nil)
        let env = try Environment(pressurePa: 101_325, temperatureK: 288.15, source: .standard)
        func make(seq: Int) throws -> Shot {
            try Shot(
                id: UUID(), sessionID: UUID(), sequence: seq, mode: .quickShot, swingHandedness: .left, clubSnapshot: snap,
                calibrationID: UUID(), impactTimeUTC: t0, metrics: [.clubSpeed: .unavailable(.clubSpeed, failure: .unsupportedMetric)],
                environment: env, versions: ShotVersions(pipeline: "t", flight: "t", deviceProfile: "t"), included: false
            )
        }
        #expect(throws: ContractError.invalidSequence(0)) { try make(seq: 0) }
        let shot = try make(seq: 3)
        let again = try decoder.decode(Shot.self, from: encoder.encode(shot))
        #expect(again == shot)
        #expect(again.included == false)
        #expect(again.metrics[.clubSpeed]?.failure == .unsupportedMetric)
        #expect(again.isSynthetic == false)
    }

    @Test func environmentRejectsNonPhysicalValues() {
        #expect(throws: ContractError.invalidEnvironment) { try Environment(pressurePa: -1, temperatureK: 288, source: .manual) }
        #expect(throws: ContractError.invalidEnvironment) { try Environment(pressurePa: 101_325, temperatureK: .nan, source: .manual) }
    }
}
