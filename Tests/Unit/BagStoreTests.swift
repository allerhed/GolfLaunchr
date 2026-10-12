import Domain
import Foundation
@testable import GolfLaunchr
import Persistence
import PersistenceTestSupport
import Testing

/// Counts calls and can be told to fail, to prove what the store does when storage misbehaves.
actor RecordingRepository: ClubRepository {
    var stored: Bag?
    var saves = 0
    var failLoad = false
    var failSave = false

    init(stored: Bag? = nil) {
        self.stored = stored
    }

    func setFailLoad(_ value: Bool) {
        failLoad = value
    }

    func setFailSave(_ value: Bool) {
        failSave = value
    }

    func loadBag() throws -> Bag? {
        if failLoad {
            throw PersistenceError.storageFailure("load failed")
        }
        return stored
    }

    func saveBag(_ bag: Bag) throws {
        if failSave {
            throw PersistenceError.storageFailure("save failed")
        }
        saves += 1
        stored = bag
    }
}

@MainActor
struct BagStoreTests {
    let en = Locale(identifier: "en_US")
    let sv = Locale(identifier: "sv_SE")

    func store(_ repo: RecordingRepository, names: @escaping (SeedClub) -> String = { "S-\($0)" }) -> BagStore {
        BagStore(repository: repo, seedName: names, now: { Date(timeIntervalSince1970: 1_791_716_400) })
    }

    /// A1: first load seeds and saves exactly once; a second load never re-seeds.
    @Test func firstLoadSeedsOnceAndNeverAgain() async {
        let repo = RecordingRepository()
        let s = store(repo)
        await s.load()
        #expect(s.loadState == .loaded && s.bag.clubs.count == 13 && s.bag.seeded)
        #expect(await repo.saves == 1)
        await s.load()
        #expect(await repo.saves == 1)
        // The golfer archives everything: still no re-seed on the next launch.
        for club in s.bag.active {
            await s.archive(club.id)
        }
        let relaunched = store(repo)
        await relaunched.load()
        #expect(relaunched.bag.active.isEmpty && relaunched.bag.clubs.count == 13)
    }

    /// A2: seed names are localised once; afterwards they are the golfer's data.
    @Test func storedNamesAreNotRetranslatedWhenTheLanguageChanges() async {
        var bag = Bag.seeded { $0 == .iron7 ? "Järn 7" : "x\($0)" }
        let repo = RecordingRepository(stored: bag)
        let english = store(repo) { _ in "7 iron" } // the app is now English
        await english.load()
        #expect(english.bag.clubs.contains { $0.name == "Järn 7" })
        #expect(await repo.saves == 0)
        bag = english.bag
    }

    @Test func aStoreThatCannotBeReadIsAnErrorAndIsNeverSeededOver() async {
        let repo = RecordingRepository(stored: Bag.seeded { "\($0)" })
        await repo.setFailLoad(true)
        let s = store(repo)
        await s.load()
        guard case .failed = s.loadState else { Issue.record("expected failed"); return }
        #expect(s.bag.clubs.isEmpty)
        #expect(await repo.saves == 0) // nothing was written over the unreadable data
        let none = BagStore(repository: nil, failureMessage: "no storage", seedName: { "\($0)" })
        await none.load()
        #expect(none.loadState == .failed("no storage"))
    }

    /// A1: a failed save leaves what is shown unchanged.
    @Test func aFailedSaveKeepsTheBagAndReportsIt() async throws {
        let repo = RecordingRepository()
        let s = store(repo)
        await s.load()
        let before = s.bag
        await repo.setFailSave(true)
        let first = try #require(s.bag.active.first)
        #expect(await s.archive(first.id) == false)
        #expect(s.bag == before)
        #expect(s.lastError == .saveFailed)
        await repo.setFailSave(false)
        #expect(await s.archive(first.id))
        #expect(s.lastError == nil && s.bag.archived.count == 1)
    }

    @Test func changesAreWrittenBeforeTheyAreShown() async throws {
        let repo = RecordingRepository()
        let s = store(repo)
        await s.load()
        let target = try #require(s.bag.active.first)
        await s.archive(target.id)
        #expect(await repo.stored == s.bag)
        await s.restore(target.id)
        #expect(await repo.stored == s.bag)
        await s.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(await repo.stored == s.bag)
        #expect(s.bag.active.map(\.sortOrder) == Array(0 ... 12))
    }

    @Test func restoringIntoANameClashIsRefusedWithAReason() async throws {
        let repo = RecordingRepository(stored: Bag())
        let s = store(repo)
        await s.load()
        s.beginAdd()
        s.draft?.name = "7 iron"
        #expect(await s.saveDraft(locale: en))
        let old = try #require(s.bag.active.first)
        await s.archive(old.id)
        s.beginAdd()
        s.draft?.name = "7 iron"
        #expect(await s.saveDraft(locale: en))
        #expect(await s.restore(old.id) == false)
        #expect(s.lastError == .validation(.duplicateActiveName))
    }

    // MARK: editor

    @Test func addingAClubWithASwedishDecimalCommaLoft() async throws {
        let s = store(RecordingRepository(stored: Bag()))
        await s.load()
        s.beginAdd()
        s.draft?.name = "  Test 7i "
        s.draft?.loftText = "34,5"
        #expect(await s.saveDraft(locale: sv))
        #expect(s.draft == nil)
        let club = try #require(s.bag.active.last)
        #expect(club.name == "Test 7i")
        #expect(abs((club.loftRad ?? 0) - 34.5 * .pi / 180) < 1e-12)
    }

    @Test func aBadLoftKeepsTheEditorOpenAndNamesTheProblem() async throws {
        let s = store(RecordingRepository(stored: Bag()))
        await s.load()
        s.beginAdd()
        s.draft?.name = "X"
        s.draft?.loftText = "abc"
        let draft = try #require(s.draft)
        #expect(s.validation(of: draft, locale: en) == .loftNotFinite)
        #expect(await s.saveDraft(locale: en) == false)
        #expect(s.draft != nil && s.lastError == .validation(.loftNotFinite))
        s.draft?.loftText = "99"
        #expect(try s.validation(of: #require(s.draft), locale: en) == .loftOutOfRange)
        s.draft?.loftText = ""
        #expect(try s.validation(of: #require(s.draft), locale: en) == nil) // empty loft = not set
        s.draft?.loftText = "NaN"
        #expect(try s.validation(of: #require(s.draft), locale: en) == .loftNotFinite)
    }

    @Test func editingShowsTheLoftInTheLocaleAndKeepsTheClubsOwnNameValid() async throws {
        var bag = Bag()
        let club = try bag.add(name: "SW", category: .wedge, loftDegrees: 56.5)
        let s = store(RecordingRepository(stored: bag))
        await s.load()
        s.beginEdit(club, locale: sv)
        #expect(s.draft?.loftText == "56,5" && s.draft?.isPristine == true)
        s.beginEdit(club, locale: en)
        #expect(s.draft?.loftText == "56.5")
        #expect(try s.validation(of: #require(s.draft), locale: en) == nil) // its own name is not a duplicate
        s.draft?.name = "Sand wedge"
        #expect(s.draft?.isPristine == false)
        #expect(await s.saveDraft(locale: en))
        #expect(s.bag.snapshot(club.id)?.name == "Sand wedge" && s.bag.snapshot(club.id)?.loftRevision == 0)
    }

    @Test func theDraftLivesInTheStoreSoRotationCannotLoseIt() async {
        let s = store(RecordingRepository(stored: Bag()))
        await s.load()
        s.beginAdd()
        s.draft?.name = "Half typed"
        // The shell rebuilds its views on rotation; the store (and the draft) is untouched.
        #expect(s.draft?.name == "Half typed")
        s.cancelDraft()
        #expect(s.draft == nil && s.bag.clubs.isEmpty)
    }

    @Test func loftTextParsingAndFormatting() {
        #expect(BagStore.parseLoft("", locale: sv) == .unset)
        #expect(BagStore.parseLoft("  ", locale: sv) == .unset)
        #expect(BagStore.parseLoft("56,5", locale: sv) == .value(56.5))
        #expect(BagStore.parseLoft("56.5", locale: sv) == .value(56.5))
        #expect(BagStore.parseLoft("x", locale: en) == .invalid)
        #expect(BagStore.loftText(radians: 56 * .pi / 180, locale: sv) == "56")
        #expect(BagStore.loftText(radians: 34.5 * .pi / 180, locale: sv) == "34,5")
    }
}

@MainActor
struct DraftBindingTests {
    /// Regression: a stale write after the editor closed must not bring the draft back.
    @Test func aStaleFieldWriteAfterSavingDoesNotReopenTheEditor() async {
        let repo = RecordingRepository(stored: Bag())
        let s = BagStore(repository: repo, seedName: { "\($0)" })
        await s.load()
        s.beginAdd()
        s.draft?.name = "Saved"
        #expect(await s.saveDraft(locale: Locale(identifier: "en_US")))
        #expect(s.draft == nil)
        ClubEditBindingRule.write(ClubDraft(name: ""), into: s) // what a dismissing text field does
        #expect(s.draft == nil)
        s.beginAdd()
        ClubEditBindingRule.write(ClubDraft(name: "typed"), into: s) // while editing, writes still apply
        #expect(s.draft?.name == "typed")
    }
}
