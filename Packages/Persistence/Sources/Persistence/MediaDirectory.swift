import CryptoKit
import Foundation

public enum MediaError: Error, Equatable {
    /// The relative path escapes the media folder or is not a plain relative path.
    case invalidPath(String)
    case alreadyExists(String)
    case missing(String)
}

public struct StagedFile: Sendable, Equatable {
    public let url: URL
}

public struct OrphanReport: Sendable, Equatable {
    /// Files left in `staging/` by an interrupted write. They were never referenced and are safe to delete.
    public let stagedLeftovers: [URL]
    /// Committed media files (relative paths) that no database record references.
    public let unreferenced: [String]

    public var isEmpty: Bool {
        stagedLeftovers.isEmpty && unreferenced.isEmpty
    }
}

/// Media files live outside the database (F20). A file is first written to `staging/`, then moved atomically into `media/`
/// once the database record that references it is ready. After a crash, `scanOrphans` finds what was left behind.
public struct MediaDirectory: Sendable {
    public let root: URL
    var stagingURL: URL {
        root.appendingPathComponent("staging", isDirectory: true)
    }

    var mediaURL: URL {
        root.appendingPathComponent("media", isDirectory: true)
    }

    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)
    }

    public func stage(_ data: Data) throws -> StagedFile {
        let url = stagingURL.appendingPathComponent("\(UUID().uuidString).part")
        try data.write(to: url, options: .atomic)
        return StagedFile(url: url)
    }

    /// Moves a staged file to `relativePath` under `media/`. Never overwrites an existing file.
    public func commit(_ staged: StagedFile, as relativePath: String) throws {
        let destination = try resolve(relativePath)
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw MediaError.alreadyExists(relativePath) }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: staged.url, to: destination)
    }

    public func exists(_ relativePath: String) throws -> Bool {
        try FileManager.default.fileExists(atPath: resolve(relativePath).path)
    }

    /// SHA-256 of a committed file, hex encoded.
    public func checksum(_ relativePath: String) throws -> String {
        let url = try resolve(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { throw MediaError.missing(relativePath) }
        return try SHA256.hash(data: Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }

    /// Lists staged leftovers and committed files not in `referenced` (relative paths the database knows about).
    public func scanOrphans(referenced: Set<String>) throws -> OrphanReport {
        let staged = try FileManager.default.contentsOfDirectory(at: stagingURL, includingPropertiesForKeys: nil)
        var committed: [String] = []
        // The enumerator reports resolved paths (/private/var/...), so resolve the base the same way before stripping it.
        let base = mediaURL.resolvingSymlinksInPath().path
        if let walker = FileManager.default.enumerator(at: mediaURL, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let url as URL in walker where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                committed.append(String(url.resolvingSymlinksInPath().path.dropFirst(base.count + 1)))
            }
        }
        return OrphanReport(
            stagedLeftovers: staged.sorted { $0.path < $1.path },
            unreferenced: committed.filter { !referenced.contains($0) }.sorted()
        )
    }

    /// Deletes exactly what the report lists. Referenced files are never in a report.
    public func removeOrphans(_ report: OrphanReport) throws {
        for url in report.stagedLeftovers {
            try FileManager.default.removeItem(at: url)
        }
        for path in report.unreferenced {
            try FileManager.default.removeItem(at: resolve(path))
        }
    }

    /// A relative path must be non-empty, not absolute and must not contain `..` or empty components.
    private func resolve(_ relativePath: String) throws -> URL {
        let parts = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/"), !parts.contains(where: { $0.isEmpty || $0 == ".." || $0 == "." }) else {
            throw MediaError.invalidPath(relativePath)
        }
        return mediaURL.appendingPathComponent(relativePath)
    }
}
