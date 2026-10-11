import Foundation

/// Synthetic schema fixture from spec section 6. Test-only: not a real record and not evidence of accuracy.
enum ContractFixtures {
    static let shotJSON = """
    {
      "schemaVersion": "1.0",
      "id": "11111111-1111-4111-8111-111111111111",
      "sessionId": "22222222-2222-4222-8222-222222222222",
      "sequence": 1,
      "mode": "practice",
      "swingHandedness": "right",
      "clubSnapshot": {"id": "33333333-3333-4333-8333-333333333333", "name": "7 iron", "loftRad": 0.5235987756},
      "calibrationId": "44444444-4444-4444-8444-444444444444",
      "impactTimeUTC": "2026-10-11T11:00:00Z",
      "coordinateConvention": "targetForward-rightPositive-upPositive",
      "metrics": {
        "ballSpeed": {"value": 45.0, "unit": "m/s", "provenance": "measured", "quality": "valid", "uncertainty95": null},
        "clubSpeed": {"value": null, "unit": "m/s", "provenance": "unavailable", "quality": "unsupported", "uncertainty95": null},
        "verticalLaunch": {"value": 0.3141592654, "unit": "rad", "provenance": "measured", "quality": "valid", "uncertainty95": null},
        "spinRate": {"value": 628.3185307, "unit": "rad/s", "provenance": "estimated", "quality": "provisional", "uncertainty95": null},
        "carry": {"value": 130.0, "unit": "m", "provenance": "estimated", "quality": "provisional", "uncertainty95": null}
      },
      "environment": {"pressurePa": 101325, "temperatureK": 288.15, "source": "standard"},
      "versions": {"pipeline": "demo-1", "flight": "demo-1", "deviceProfile": "fixture-only"},
      "included": true,
      "mediaId": null,
      "isSynthetic": true
    }
    """

    /// Fixture with one targeted substitution, for rejection tests.
    static func shotJSON(replacing target: String, with replacement: String) -> Data {
        Data(shotJSON.replacingOccurrences(of: target, with: replacement).utf8)
    }
}
