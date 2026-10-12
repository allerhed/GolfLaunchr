import Foundation
@testable import Persistence
import Testing

struct MediaDirectoryTests {
    func make() throws -> MediaDirectory {
        try MediaDirectory(root: FileManager.default.temporaryDirectory.appendingPathComponent("golflaunchr-media-\(UUID().uuidString)"))
    }

    @Test func stagingThenCommittingMovesTheFileAndKeepsItsChecksum() throws {
        let media = try make()
        let data = Data("clip bytes".utf8)
        let staged = try media.stage(data)
        #expect(FileManager.default.fileExists(atPath: staged.url.path))
        try media.commit(staged, as: "2026/10/shot-1/impact.mov")
        #expect(!FileManager.default.fileExists(atPath: staged.url.path))
        #expect(try media.exists("2026/10/shot-1/impact.mov"))
        #expect(try media.checksum("2026/10/shot-1/impact.mov").count == 64)
    }

    @Test func checksumMatchesAKnownSHA256() throws {
        let media = try make()
        try media.commit(media.stage(Data("abc".utf8)), as: "a.bin")
        #expect(try media.checksum("a.bin") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") // SHA-256("abc")
    }

    @Test func commitNeverOverwritesAnExistingFile() throws {
        let media = try make()
        try media.commit(media.stage(Data("first".utf8)), as: "x.bin")
        #expect(throws: MediaError.alreadyExists("x.bin")) { try media.commit(media.stage(Data("second".utf8)), as: "x.bin") }
        #expect(try media.checksum("x.bin") == "a7937b64b8caa58f03721bb6bacf5c78cb235febe0e70b1b84cd99541461a08e") // SHA-256("first")
    }

    @Test(arguments: ["../escape", "/abs/path", "a/../b", "", "a//b", "./a", ".."])
    func unsafePathsAreRejected(path: String) throws {
        let media = try make()
        let staged = try media.stage(Data("x".utf8))
        #expect(throws: MediaError.invalidPath(path)) { try media.commit(staged, as: path) }
        #expect(throws: MediaError.invalidPath(path)) { try media.exists(path) }
    }

    @Test func orphansAreFoundAndOnlyOrphansAreRemoved() throws {
        let media = try make()
        try media.commit(media.stage(Data("kept".utf8)), as: "keep/a.mov")
        try media
            .commit(media.stage(Data("lost".utf8)), as: "lost/b.mov") // the database never learned about it (crash between move and record)
        let leftover = try media.stage(Data("partial".utf8)) // crash while staging
        let report = try media.scanOrphans(referenced: ["keep/a.mov"])
        #expect(report.unreferenced == ["lost/b.mov"])
        #expect(report.stagedLeftovers == [leftover.url] || report.stagedLeftovers
            .map(\.lastPathComponent) == [leftover.url.lastPathComponent])
        try media.removeOrphans(report)
        #expect(try media.exists("keep/a.mov"))
        #expect(try !media.exists("lost/b.mov"))
        #expect(!FileManager.default.fileExists(atPath: leftover.url.path))
        #expect(try media.scanOrphans(referenced: ["keep/a.mov"]).isEmpty)
    }

    @Test func aReferencedFileIsNeverReportedEvenIfMissingFromTheDatabaseListByCase() throws {
        let media = try make()
        try media.commit(media.stage(Data("x".utf8)), as: "Keep.mov")
        #expect(try media.scanOrphans(referenced: ["keep.mov"]).unreferenced == ["Keep.mov"]) // paths are exact, never fuzzy-matched
    }

    @Test func checksumOfAMissingFileIsAnError() throws {
        #expect(throws: MediaError.missing("nope.mov")) { try make().checksum("nope.mov") }
    }
}
