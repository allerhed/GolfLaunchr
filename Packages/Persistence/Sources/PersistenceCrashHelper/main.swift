import Domain
import Foundation
import Persistence

/// Test helper: commits one shot and may kill itself with SIGKILL at a chosen point, to prove crash atomicity.
/// usage: PersistenceCrashHelper <db path> <shot.json> <ledger.json> <none|afterShotInsert|afterLedgerInsert|afterCommit>
let args = CommandLine.arguments
guard args.count == 5 else {
    FileHandle.standardError.write(Data("usage: PersistenceCrashHelper <db> <shot.json> <ledger.json> <fault>\n".utf8))
    exit(2)
}

do {
    let decoder = ContractJSON.decoder()
    let shot = try decoder.decode(Shot.self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
    let ledger = try decoder.decode(LedgerEntry.self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
    let store = try SQLiteStore(url: URL(fileURLWithPath: args[1]), allowsSynthetic: true)
    #if DEBUG
        if let point = CommitFault(rawValue: args[4]) {
            await store.armFault(point, action: .killProcess)
        }
    #endif
    let receipt = try await store.commitAccepted(shot, ledger: ledger)
    print("committed duplicate=\(receipt.wasAlreadyCommitted)")
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
