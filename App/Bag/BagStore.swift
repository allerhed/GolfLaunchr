import Domain
import Formatting
import Foundation
import Observation
import Persistence

/// Why a bag change did not happen. The bag is never partly changed.
enum BagStoreError: Equatable {
    case validation(ClubValidationError)
    /// The change was valid but could not be written; the previous bag is still shown.
    case saveFailed
}

/// What the editor is editing. Lives in the store (not the view) so typed text survives rotation, which rebuilds the shell.
struct ClubDraft: Equatable {
    var editingID: UUID?
    var name = ""
    var category = ClubCategory.iron
    var loftText = ""
    var brand = ""
    var model = ""
    /// The values the editor opened with, to tell "untouched" from "invalid".
    var original: Original?

    struct Original: Equatable {
        let name: String, category: ClubCategory, loftText: String, brand: String, model: String
    }

    var isPristine: Bool {
        guard let original else { return name.isEmpty && loftText.isEmpty && brand.isEmpty && model.isEmpty && category == .iron }
        return original == Original(name: name, category: category, loftText: loftText, brand: brand, model: model)
    }
}

/// Holds the golfer's bag, applies every change through the `Bag` rules and writes it before showing it (F08).
@MainActor @Observable
final class BagStore {
    enum LoadState: Equatable {
        case idle, loaded
        case failed(String)
    }

    private(set) var bag = Bag()
    private(set) var loadState = LoadState.idle
    private(set) var lastError: BagStoreError?
    var draft: ClubDraft?
    var showsArchived = false

    private var loadTask: Task<Void, Never>?
    private let repository: (any ClubRepository)?
    private let seedName: (SeedClub) -> String
    private let now: () -> Date

    init(
        repository: (any ClubRepository)?,
        failureMessage: String? = nil,
        seedName: @escaping (SeedClub) -> String,
        now: @escaping () -> Date = Date.init
    ) {
        self.repository = repository
        self.seedName = seedName
        self.now = now
        if repository == nil {
            loadState = .failed(failureMessage ?? "No storage available")
        }
    }

    // MARK: loading

    /// After all practice data was deleted the stored bag is gone: read again, which seeds the default bag as on a first launch.
    func reloadAfterDeletion() async {
        loadTask = nil
        loadState = .idle
        await load()
    }

    /// Reads the bag. Only a store that has never held a bag is seeded; a bag that exists but cannot be read is an error and
    /// is left alone (never re-seeded over).
    func load() async {
        guard let repository, loadState == .idle || isFailed else { return }
        // Concurrent callers wait for the load in flight: two loads that both found no bag would seed twice, and the second
        // save would replace the first with clubs that have different IDs.
        if let running = loadTask {
            await running.value
            return
        }
        let task = Task { @MainActor in await self.read(from: repository) }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func read(from repository: any ClubRepository) async {
        do {
            if let stored = try await repository.loadBag() {
                bag = stored
            } else {
                let seeded = Bag.seeded(names: seedName)
                try await repository.saveBag(seeded)
                bag = seeded
            }
            loadState = .loaded
        } catch {
            loadState = .failed("\(error)")
        }
    }

    private var isFailed: Bool {
        if case .failed = loadState {
            return true
        }
        return false
    }

    // MARK: changes

    @discardableResult
    func archive(_ id: UUID) async -> Bool {
        await apply { bag throws(ClubValidationError) in try bag.archive(id, now: self.now()) }
    }

    @discardableResult
    func restore(_ id: UUID) async -> Bool {
        await apply { bag throws(ClubValidationError) in try bag.restore(id) }
    }

    @discardableResult
    func move(fromOffsets: IndexSet, toOffset: Int) async -> Bool {
        await apply { $0.move(fromOffsets: fromOffsets, toOffset: toOffset) }
    }

    /// Applies `change` to a copy, writes the copy, and only then shows it.
    private func apply(_ change: (inout Bag) throws(ClubValidationError) -> Void) async -> Bool {
        guard let repository, loadState == .loaded else { return false }
        var copy = bag
        do {
            try change(&copy)
        } catch {
            lastError = .validation(error)
            return false
        }
        do {
            try await repository.saveBag(copy)
        } catch {
            lastError = .saveFailed
            return false
        }
        bag = copy
        lastError = nil
        return true
    }

    // MARK: editor

    func beginAdd() {
        lastError = nil
        draft = ClubDraft()
    }

    func beginEdit(_ club: Club, locale: Locale) {
        lastError = nil
        let loft = club.loftRad.map { Self.loftText(radians: $0, locale: locale) } ?? ""
        var value = ClubDraft(
            editingID: club.id, name: club.name, category: club.category, loftText: loft, brand: club.brand ?? "", model: club.model ?? ""
        )
        value.original = ClubDraft.Original(
            name: value.name,
            category: value.category,
            loftText: loft,
            brand: value.brand,
            model: value.model
        )
        draft = value
    }

    func cancelDraft() {
        draft = nil
        lastError = nil
    }

    /// The reason the draft cannot be saved, or nil if it can.
    func validation(of draft: ClubDraft, locale: Locale) -> ClubValidationError? {
        let loft = Self.parseLoft(draft.loftText, locale: locale)
        if case .invalid = loft {
            return .loftNotFinite
        }
        do {
            _ = try bag.validate(name: draft.name, loftDegrees: loft.degrees, editing: draft.editingID)
            return nil
        } catch {
            return error
        }
    }

    /// Saves the draft (new club or edit). Closes the editor only when the change was written.
    @discardableResult
    func saveDraft(locale: Locale) async -> Bool {
        guard let draft else { return false }
        let loft = Self.parseLoft(draft.loftText, locale: locale)
        if case .invalid = loft {
            lastError = .validation(.loftNotFinite)
            return false
        }
        let saved = await apply { bag throws(ClubValidationError) in
            if let id = draft.editingID {
                try bag.update(
                    id,
                    name: draft.name,
                    category: draft.category,
                    loftDegrees: loft.degrees,
                    brand: draft.brand,
                    model: draft.model
                )
            } else {
                try bag.add(name: draft.name, category: draft.category, loftDegrees: loft.degrees, brand: draft.brand, model: draft.model)
            }
        }
        if saved {
            self.draft = nil
        }
        return saved
    }

    // MARK: loft text

    enum ParsedLoft: Equatable {
        case unset
        case value(Double)
        case invalid

        var degrees: Double? {
            if case let .value(v) = self {
                v
            } else {
                nil
            }
        }
    }

    /// Empty means "not set". Anything that is not a locale-valid number is invalid (the Swedish comma is accepted).
    static func parseLoft(_ text: String, locale: Locale) -> ParsedLoft {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return .unset }
        guard let value = NumberInput.parse(text, locale: locale) else { return .invalid }
        return .value(value)
    }

    static func loftText(radians: Double, locale: Locale) -> String {
        (radians * 180 / .pi).formatted(.number.precision(.fractionLength(0 ... 1)).grouping(.never).locale(locale))
    }
}
