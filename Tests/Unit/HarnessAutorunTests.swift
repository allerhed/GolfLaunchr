#if CAPTURE_HARNESS
    @testable import GolfLaunchr
    import Testing

    struct HarnessAutorunTests {
        @Test func parsesAllArguments() {
            let c = HarnessAutorunConfig.parse(
                ["app", "-harnessAutorun", "60", "-harnessExposure", "2000", "-harnessTrigger", "motion", "-harnessSaveEvery", "5"]
            )
            #expect(c == HarnessAutorunConfig(
                seconds: 60,
                exposure: .ms2000,
                trigger: .motion,
                saveEvery: 5,
                lens: nil,
                maxMbit: nil,
                discardLate: false
            ))
            let d = HarnessAutorunConfig.parse(["app", "-harnessAutorun", "9", "-harnessLens", "wide", "-harnessMaxMbit", "150"])
            #expect(d?.lens == "wide" && d?.maxMbit == 150 && d?.discardLate == false)
            #expect(HarnessAutorunConfig.parse(["app", "-harnessAutorun", "9", "-harnessDiscard"])?.discardLate == true)
            #expect(HarnessAutorunConfig.parse(["app", "-harnessAutorun", "9", "-harnessMaxMbit", "0"])?.maxMbit == nil)
        }

        @Test func defaultsAndMissingFlag() {
            #expect(HarnessAutorunConfig.parse(["app"]) == nil)
            let c = HarnessAutorunConfig.parse(["app", "-harnessAutorun", "30"])
            #expect(c == HarnessAutorunConfig(
                seconds: 30,
                exposure: .auto,
                trigger: .manual,
                saveEvery: 10,
                lens: nil,
                maxMbit: nil,
                discardLate: false
            ))
        }

        @Test(arguments: [
            ["-harnessAutorun"],
            ["-harnessAutorun", "abc"],
            ["-harnessAutorun", "0"],
            ["-harnessAutorun", "-5"],
            ["-harnessAutorun", "inf"]
        ])
        func invalidDurationsAreRejected(args: [String]) {
            #expect(HarnessAutorunConfig.parse(["app"] + args) == nil)
        }

        @Test func unknownExposureFallsBackToAutoAndSaveIntervalHasAFloor() {
            let c = HarnessAutorunConfig.parse(["app", "-harnessAutorun", "20", "-harnessExposure", "999", "-harnessSaveEvery", "0.1"])
            #expect(c?.exposure == .auto)
            #expect(c?.saveEvery == 1)
        }
    }
#endif
