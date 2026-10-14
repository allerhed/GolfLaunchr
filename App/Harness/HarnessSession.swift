#if CAPTURE_HARNESS
    import AudioToolbox
    import Capture
    import Foundation
    import UIKit

    /// What a harness clip is for (garage / bay sessions with a reference launch monitor).
    enum RecordingKind: String, CaseIterable, Identifiable {
        case strike, negative, background, scale
        var id: String {
            rawValue
        }
    }

    /// File locations and device facts for the manifest.
    extension HarnessModel {
        /// Physical orientation name; capture must be landscape (spec F22).
        static func orientationName() -> String {
            switch UIDevice.current.orientation {
            case .landscapeLeft: "landscapeLeft"
            case .landscapeRight: "landscapeRight"
            case .portrait: "portrait"
            case .portraitUpsideDown: "portraitUpsideDown"
            case .faceUp: "faceUp"
            case .faceDown: "faceDown"
            default: "unknown"
            }
        }

        static func clipDirectory() throws -> URL {
            let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = docs.appendingPathComponent("G1", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }

        static func deviceInfo() -> DeviceInfo {
            var size = 0
            sysctlbyname("hw.machine", nil, &size, nil, 0)
            var bytes = [CChar](repeating: 0, count: max(size, 1))
            sysctlbyname("hw.machine", &bytes, &size, nil, 0)
            let machine = String(cString: bytes)
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
            return DeviceInfo(machine: machine, osVersion: ProcessInfo.processInfo.operatingSystemVersionString, appBuild: build)
        }
    }

    /// Block-by-block numbering and the session log, so every clip can be paired with the reference monitor's export.
    /// DEBUG HARNESS ONLY.
    extension HarnessModel {
        /// Next 1-based number for a block and kind, continuing after an app restart from what the log already holds.
        func nextSequence(block: String, kind: RecordingKind) -> Int {
            let key = "\(block)|\(kind.rawValue)"
            if sequenceCounters[key] == nil {
                sequenceCounters[key] = Self.loggedCount(block: block, kind: kind.rawValue)
            }
            let next = (sequenceCounters[key] ?? 0) + 1
            sequenceCounters[key] = next
            return next
        }

        /// The number the next clip of the current block and kind will get (for the on-screen label).
        var upcomingSequence: Int {
            let key = "\(block)|\(recordingKind.rawValue)"
            return (sequenceCounters[key] ?? Self.loggedCount(block: block, kind: recordingKind.rawValue)) + 1
        }

        static func loggedCount(block: String, kind: String) -> Int {
            guard let dir = try? clipDirectory(),
                  let text = try? String(contentsOf: dir.appendingPathComponent(SessionLog.fileName), encoding: .utf8) else { return 0 }
            let rows = text.split(separator: "\n").dropFirst().map { SessionLog.split(String($0)) }
            guard let b = SessionLog.columns.firstIndex(of: "block"), let k = SessionLog.columns.firstIndex(of: "kind"),
                  let c = SessionLog.columns.firstIndex(of: "clip") else { return 0 }
            let clips = Set(rows.filter { $0.count == SessionLog.columns.count && $0[b] == block && $0[k] == kind }.map { $0[c] })
            return clips.count
        }

        func logRow(_ manifest: CaptureManifest, stem: String) {
            do {
                let file = try Self.clipDirectory().appendingPathComponent(SessionLog.fileName)
                try SessionLog.append(SessionLog.row(manifest, clipStem: stem, exposurePreset: exposurePreset.rawValue), to: file)
            } catch {
                message = "Session log write failed: \(error)"
            }
        }

        /// A short sound when a clip is saved, so the golfer knows the phone caught the shot without walking round to it.
        func confirmSaved() {
            AudioServicesPlaySystemSound(1057)
        }

        /// Marks the last saved clip (void false trigger, reference missed, mis-hit). The manifest is rewritten and a new log row is
        /// appended; the latest row for a clip wins when pairing.
        func markLast(_ note: String) {
            guard let clip = clips.first else { return }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                var manifest = try decoder.decode(CaptureManifest.self, from: Data(contentsOf: clip.manifest))
                var shot = manifest.shot ?? ShotInfo(club: club, lighting: lighting, location: location, trigger: trigger.rawValue)
                shot.outcomeNotes = [shot.outcomeNotes, note].compactMap(\.self).joined(separator: "; ")
                manifest.shot = shot
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(manifest).write(to: clip.manifest, options: .atomic)
                logRow(manifest, stem: clip.movie.deletingPathExtension().lastPathComponent)
                message = "Marked \(clip.movie.lastPathComponent): \(note)"
            } catch {
                message = "Could not mark the last clip: \(error)"
            }
        }
    }
#endif
