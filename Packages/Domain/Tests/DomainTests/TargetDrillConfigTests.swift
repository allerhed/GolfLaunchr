@testable import Domain
import Foundation
import Testing

struct TargetDrillConfigTests {
    @Test func validConfigsAreAccepted() throws {
        _ = try TargetDrillConfig(targetCarryM: 5, longitudinalToleranceM: 1, attempts: 1)
        _ = try TargetDrillConfig(targetCarryM: 400, longitudinalToleranceM: 50, lateralToleranceM: 10, attempts: 100)
    }

    @Test func nonsenseIsRejectedWithATypedError() {
        #expect(throws: ContractError.invalidDrillConfig("target")) { try TargetDrillConfig(targetCarryM: 0) }
        #expect(throws: ContractError.invalidDrillConfig("target")) { try TargetDrillConfig(targetCarryM: .nan) }
        #expect(throws: ContractError.invalidDrillConfig("target")) { try TargetDrillConfig(targetCarryM: 401) }
        #expect(throws: ContractError.invalidDrillConfig("longitudinalTolerance")) { try TargetDrillConfig(longitudinalToleranceM: 0) }
        #expect(throws: ContractError.invalidDrillConfig("longitudinalTolerance")) {
            try TargetDrillConfig(targetCarryM: 10, longitudinalToleranceM: 11)
        }
        #expect(throws: ContractError.invalidDrillConfig("lateralTolerance")) { try TargetDrillConfig(lateralToleranceM: -1) }
        #expect(throws: ContractError.invalidDrillConfig("attempts")) { try TargetDrillConfig(attempts: 0) }
        #expect(throws: ContractError.invalidDrillConfig("attempts")) { try TargetDrillConfig(attempts: 101) }
        #expect(throws: ContractError.invalidDrillConfig("clubs")) { try TargetDrillConfig(clubIDs: []) }
    }

    @Test func aSessionKeepsItsDrillConfigurationThroughEncodingAndDecoding() throws {
        let club = UUID()
        let config = try TargetDrillConfig(
            targetCarryM: 137.5, longitudinalToleranceM: 4, lateralToleranceM: 6, attempts: 12, clubIDs: [club]
        )
        let session = try Session(mode: .target, createdAt: Date(timeIntervalSince1970: 1_791_716_400), drill: config)
        let data = try JSONEncoder().encode(session)
        let back = try JSONDecoder().decode(Session.self, from: data)
        #expect(back.drill == config && back == session)
    }

    @Test func sessionsStoredBeforeDrillsExistStillDecode() throws {
        let session = try Session(mode: .practice, createdAt: Date(timeIntervalSince1970: 1_791_716_400))
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        json["drill"] = nil
        let old = try JSONSerialization.data(withJSONObject: json)
        #expect(try JSONDecoder().decode(Session.self, from: old).drill == nil)
    }

    @Test func aCorruptStoredConfigFailsToDecodeInsteadOfBecomingADefault() throws {
        let json = #"{"targetCarryM":-5,"longitudinalToleranceM":5,"attempts":10}"#
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(TargetDrillConfig.self, from: Data(json.utf8)) }
    }
}
