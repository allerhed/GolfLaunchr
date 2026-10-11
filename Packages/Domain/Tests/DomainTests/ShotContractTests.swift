@testable import Domain
import Foundation
import Testing

struct ShotContractTests {
    let decoder = ContractJSON.decoder()
    let encoder = ContractJSON.encoder()

    func decodeFixture() throws -> Shot {
        try decoder.decode(Shot.self, from: Data(ContractFixtures.shotJSON.utf8))
    }

    @Test func specFixtureDecodes() throws {
        let shot = try decodeFixture()
        #expect(shot.id == UUID(uuidString: "11111111-1111-4111-8111-111111111111"))
        #expect(shot.sequence == 1)
        #expect(shot.mode == .practice)
        #expect(shot.swingHandedness == .right)
        #expect(shot.clubSnapshot.name == "7 iron")
        #expect(shot.value(.ballSpeed) == 45.0)
        #expect(shot.metrics[.ballSpeed]?.provenance == .measured)
        #expect(shot.metrics[.spinRate]?.provenance == .estimated)
        #expect(shot.metrics[.carry]?.quality == .provisional)
        #expect(shot.impactTimeUTC == Date(timeIntervalSince1970: 1_791_716_400))
        #expect(shot.isSynthetic)
        #expect(shot.mediaID == nil)
    }

    @Test func missingMetricIsNilNeverZero() throws {
        let shot = try decodeFixture()
        #expect(shot.value(.clubSpeed) == nil) // present but unavailable
        #expect(shot.metrics[.clubSpeed]?.provenance == .unavailable)
        #expect(shot.value(.spinAxis) == nil) // never reported
        #expect(shot.metrics[.spinAxis] == nil)
    }

    @Test func roundTripPreservesEverything() throws {
        let shot = try decodeFixture()
        let again = try decoder.decode(Shot.self, from: encoder.encode(shot))
        #expect(again == shot)
    }

    @Test func encodingWritesExplicitNullsAndUnits() throws {
        let json = try #require(try String(data: encoder.encode(decodeFixture()), encoding: .utf8))
        #expect(json.contains("\"mediaId\":null"))
        #expect(json.contains("\"uncertainty95\":null"))
        #expect(json.contains("\"unit\":\"rad/s\""))
        #expect(json.contains("\"coordinateConvention\":\"targetForward-rightPositive-upPositive\""))
        let clubSpeed = "\"clubSpeed\":{\"provenance\":\"unavailable\",\"quality\":\"unsupported\","
            + "\"uncertainty95\":null,\"unit\":\"m/s\",\"value\":null}"
        #expect(json.contains(clubSpeed))
    }

    @Test func encodedKeysMatchTheSpecFixture() throws {
        struct Keys {
            let top: Set<String>, metric: Set<String>, club: Set<String>
        }
        func keys(_ data: Data) throws -> Keys {
            let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            let metrics = try #require(obj["metrics"] as? [String: [String: Any]])
            let club = try #require(obj["clubSnapshot"] as? [String: Any])
            return Keys(top: Set(obj.keys), metric: Set(metrics["ballSpeed"]?.keys.map(\.self) ?? []), club: Set(club.keys))
        }
        let spec = try keys(Data(ContractFixtures.shotJSON.utf8))
        let ours = try keys(encoder.encode(decodeFixture()))
        #expect(ours.top == spec.top)
        #expect(ours.metric == spec.metric)
        #expect(ours.club == spec.club.union(["loftRevision"])) // additive field, see DECISIONS.md
    }

    @Test func fractionalSecondsSurviveRoundTrip() throws {
        let data = ContractFixtures.shotJSON(replacing: "2026-10-11T11:00:00Z", with: "2026-10-11T11:00:00.123Z")
        let shot = try decoder.decode(Shot.self, from: data)
        let again = try decoder.decode(Shot.self, from: encoder.encode(shot))
        #expect(abs(again.impactTimeUTC.timeIntervalSince(shot.impactTimeUTC)) < 0.0005)
        #expect(abs(shot.impactTimeUTC.timeIntervalSince1970 - 1_791_716_400.123) < 0.0005)
    }

    @Test func leftHandedShotKeepsItsSnapshot() throws {
        let shot = try decoder.decode(Shot.self, from: ContractFixtures.shotJSON(replacing: "\"right\"", with: "\"left\""))
        #expect(shot.swingHandedness == .left)
    }

    @Test(arguments: [
        ("\"value\": 45.0", "\"value\": -1.0"), // negative speed
        ("\"unit\": \"m/s\", \"provenance\": \"measured\"", "\"unit\": \"m\", \"provenance\": \"measured\""), // unit mismatch
        ("\"value\": null, \"unit\": \"m/s\"", "\"value\": 40.0, \"unit\": \"m/s\""), // value on unavailable metric
        (
            "\"value\": 45.0, \"unit\": \"m/s\", \"provenance\": \"measured\"",
            "\"value\": 45.0, \"unit\": \"m/s\", \"provenance\": \"unavailable\""
        ), // value on an unavailable metric
        (
            "\"provenance\": \"estimated\", \"quality\": \"provisional\", \"uncertainty95\": null}\n",
            "\"provenance\": \"guessed\", \"quality\": \"provisional\", \"uncertainty95\": null}\n"
        ),
        ("\"ballSpeed\"", "\"ballSpeedMph\""), // unknown metric
        ("\"sequence\": 1", "\"sequence\": 0"),
        ("\"id\": \"11111111-1111-4111-8111-111111111111\"", "\"id\": \"not-a-uuid\""),
        ("\"schemaVersion\": \"1.0\"", "\"schemaVersion\": \"2.0\""),
        ("targetForward-rightPositive-upPositive", "leftPositive"),
        ("\"pressurePa\": 101325", "\"pressurePa\": 0"),
        ("\"mode\": \"practice\"", "\"mode\": \"freestyle\""),
        ("2026-10-11T11:00:00Z", "yesterday"),
        ("\"isSynthetic\": true", "\"isSynthetic\": null"),
    ])
    func invalidInputIsRejected(target: String, replacement: String) throws {
        let data = ContractFixtures.shotJSON(replacing: target, with: replacement)
        #expect(throws: DecodingError.self) { try decoder.decode(Shot.self, from: data) }
    }

    @Test func rejectionsActuallyChangeTheFixture() {
        // Guards the table above: a substitution that does not match would make its case pass vacuously.
        let targets = [
            "\"value\": 45.0", "\"unit\": \"m/s\", \"provenance\": \"measured\"", "\"value\": null, \"unit\": \"m/s\"",
            "\"ballSpeed\"", "\"sequence\": 1", "\"schemaVersion\": \"1.0\"", "targetForward-rightPositive-upPositive",
            "\"pressurePa\": 101325", "\"mode\": \"practice\"", "2026-10-11T11:00:00Z", "\"isSynthetic\": true",
            "\"value\": 45.0, \"unit\": \"m/s\", \"provenance\": \"measured\"",
            "\"provenance\": \"estimated\", \"quality\": \"provisional\", \"uncertainty95\": null}\n",
        ]
        for t in targets {
            #expect(ContractFixtures.shotJSON.contains(t), "fixture missing: \(t)")
        }
    }

    @Test func signedMetricsAllowNegativeValues() throws {
        let json = ContractFixtures.shotJSON(replacing: "\"value\": 0.3141592654", with: "\"value\": -0.05")
        #expect(try decoder.decode(Shot.self, from: json).value(.verticalLaunch) == -0.05) // downward launch
    }
}
