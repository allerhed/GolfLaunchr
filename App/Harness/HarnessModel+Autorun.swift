#if CAPTURE_HARNESS
    import AVFoundation
    import Capture
    import CaptureAV
    import Foundation
    import UIKit

    extension HarnessModel {
        /// Background tasks for one run: ordered event consumer, drop forwarding, thermal notifications and the live-panel poll.
        func makeTasks(
            stream: AsyncStream<HarnessEvent>,
            engine: HarnessEngine,
            source: AVCaptureFrameSource,
            continuation: AsyncStream<HarnessEvent>.Continuation
        ) -> [Task<Void, Never>] {
            [
                Task.detached { [weak self] in
                    for await event in stream {
                        if case let .encoderFailed(text) = event {
                            await self?.abortRun(text, reason: .interruption)
                            continue
                        }
                        if let clip = await engine.handle(event) {
                            await self?.save(clip)
                        }
                    }
                },
                Task.detached {
                    for await reason in source.drops {
                        continuation.yield(.drop(reason))
                    }
                },
                Task { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: ProcessInfo.thermalStateDidChangeNotification) {
                        self?.recordThermal()
                    }
                },
                Task { [weak self] in
                    for await _ in NotificationCenter.default.notifications(named: UIApplication.willResignActiveNotification) {
                        await self?.abortRun(
                            "Paused: the app left the foreground. Capture stops when backgrounded; press Start again.",
                            reason: .backgrounded
                        )
                    }
                },
                Task { [weak self] in
                    while !Task.isCancelled {
                        await self?.poll()
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                },
            ]
        }

        /// Applies the chosen exposure preset and reports what the camera accepted. Sets `exposurePlanText` for the live panel.
        func configureExposure(source: AVCaptureFrameSource) async throws -> ExposureSetting {
            var exposureSetting = ExposureSetting(mode: exposurePreset == .auto ? "auto" : "fixed")
            if let target = exposurePreset.durationSeconds {
                exposureSetting.requestedDurationSeconds = target
                if let plan = try await source.applyFixedExposure(durationSeconds: target) {
                    exposureSetting.appliedDurationSeconds = plan.durationSeconds
                    exposureSetting.appliedISO = plan.iso
                    exposureSetting.isoClamped = plan.isoClamped
                    exposureSetting.evShortfallStops = plan.evShortfallStops
                    exposurePlanText = String(
                        format: "1/%.0f s at ISO %.0f%@", 1 / plan.durationSeconds, plan.iso,
                        plan
                            .evShortfallStops > 0.05 ? String(format: " (%.1f stops darker than auto: ISO limit)", plan.evShortfallStops) :
                            ""
                    )
                } else {
                    exposurePlanText = "Could not read auto exposure; left on auto"
                    exposureSetting.mode = "auto"
                }
            } else {
                exposurePlanText = nil
            }
            return exposureSetting
        }

        // MARK: unattended run

        func runAutorun(_ config: HarnessAutorunConfig) async {
            let started = Date()
            autorunConfig = config
            autorunStarted = started
            loadFormats()
            exposurePreset = config.exposure
            trigger = config.trigger
            await start()
            guard phase == .running else {
                writeAutorun(AutorunSummary(
                    startedUTC: started, requestedSeconds: config.seconds, format: selectedFormatID ?? "-",
                    exposureMode: config.exposure.rawValue,
                    exposurePlan: nil, trigger: config.trigger.rawValue, frames: 0, gapEvents: 0, missingFrames: 0, droppedByReason: [:],
                    callbackMeanMs: nil, callbackP99Ms: nil, callbackMaxMs: 0, callbackOverBudgetFraction: nil, encoderMaxBacklog: 0,
                    encodeCallMeanMs: nil, encodeCallP99Ms: nil, encodeCallMaxMs: 0,
                    worstThermal: nil, clipsSaved: 0, deviceOrientation: Self.orientationName(), error: "\(phase)"
                ))
                exit(2)
            }
            var nextSave = config.saveEvery
            while Date().timeIntervalSince(started) < config.seconds, phase == .running {
                try? await Task.sleep(for: .seconds(1))
                if Date().timeIntervalSince(started) >= nextSave {
                    await saveNow()
                    nextSave += config.saveEvery
                }
            }
            if let aborted = abortedSummary {
                writeAutorun(aborted)
                exit(3)
            }
            try? await Task.sleep(for: .seconds(3)) // let the last window finish
            let summary = await autorunSummary(config, started: started)
            await stop()
            writeAutorun(summary)
            exit(0)
        }

        func autorunSummary(_ config: HarnessAutorunConfig, started: Date) async -> AutorunSummary {
            let snap = await engine?.snapshot()
            let m = metrics?.snapshot()
            let dropped = Dictionary(
                uniqueKeysWithValues: (snap?.status.dropped.countsByReason ?? [:]).map { ($0.key.rawValue, $0.value) }
            )
            return AutorunSummary(
                startedUTC: started, requestedSeconds: config.seconds,
                format: formats.first { $0.id == selectedFormatID }?.label ?? "-",
                exposureMode: config.exposure.rawValue, exposurePlan: exposurePlanText, trigger: config.trigger.rawValue,
                frames: snap?.status.clock.framesSeen ?? 0, gapEvents: snap?.status.clock.gapEvents ?? 0,
                missingFrames: snap?.status.clock.missingFrames ?? 0, droppedByReason: dropped,
                callbackMeanMs: m?.timing.meanMilliseconds, callbackP99Ms: m?.timing.p99Milliseconds,
                callbackMaxMs: m?.timing.maxMilliseconds ?? 0, callbackOverBudgetFraction: m?.timing.overBudgetFraction,
                encoderMaxBacklog: m?.maxBacklog ?? 0, encodeCallMeanMs: m?.encodeTiming.meanMilliseconds,
                encodeCallP99Ms: m?.encodeTiming.p99Milliseconds, encodeCallMaxMs: m?.encodeTiming.maxMilliseconds ?? 0,
                worstThermal: snap?.telemetry.worstThermalLevel?.rawValue,
                clipsSaved: clips.count, deviceOrientation: Self.orientationName(), error: nil
            )
        }

        func writeAutorun(_ summary: AutorunSummary) {
            guard let dir = try? Self.clipDirectory() else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let name = "autorun-\(ClipNaming.stem(createdUTC: summary.startedUTC, id: UUID())).json"
            try? encoder.encode(summary).write(to: dir.appendingPathComponent(name), options: .atomic)
        }
    }
#endif
