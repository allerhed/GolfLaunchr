import Analytics
import Domain
import Foundation
import Observation

/// Everything the analysis screens show, computed from the stored shots under ONE filter: the list, averages, gapping and dispersion
/// can never disagree about which shots are eligible (F10a). Applied filters persist across relaunch; edits happen in a draft.
@MainActor @Observable
final class AnalysisStore {
    enum Tab: String, CaseIterable, Identifiable {
        case averages, gapping, dispersion

        var id: String {
            rawValue
        }
    }

    private static let filterKey = "analysis.filter"
    private let history: HistoryStore
    private let bag: BagStore
    private let defaults: UserDefaults
    private let now: () -> Date

    var editor: AnalysisFilterEditor
    var tab = Tab.averages
    var showingFilter = false

    init(history: HistoryStore, bag: BagStore, defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.history = history
        self.bag = bag
        self.defaults = defaults
        self.now = now
        let saved = defaults.data(forKey: Self.filterKey).flatMap { try? JSONDecoder().decode(AnalysisFilter.self, from: $0) }
        // A stored empty selection could never have been applied: never restore one.
        editor = AnalysisFilterEditor(applied: saved.flatMap { $0.canApply ? $0 : nil } ?? AnalysisFilter())
    }

    var applied: AnalysisFilter {
        editor.applied
    }

    // MARK: derived data (recomputed on demand; cheap at these sizes)

    var allShots: [Shot] {
        history.summaries.flatMap { history.shots(of: $0.sessionID) }
    }

    private var bagOrder: [UUID] {
        bag.bag.active.map(\.id)
    }

    /// One order for every screen and the filter sheet: bag order first, then other clubs by name. Used for list order and colours.
    private var canonicalOrder: [UUID] {
        clubOptions.map(\.id)
    }

    /// A club's colour and symbol, from its place in the canonical order, so it looks the same in every screen whatever is selected.
    func style(for clubID: UUID) -> ClubStyle {
        ClubStyle.forPosition(canonicalOrder.firstIndex(of: clubID) ?? 0)
    }

    struct Result {
        let selection: Selection
        let profiles: [ClubProfile]
        let gap: ClubGapTable
        let points: [DispersionPoint]
        let mixedConditions: Bool
        /// Clubs eligible under every filter except the club choice (to tell if gapping shows a subset).
        let eligibleClubCount: Int
    }

    var result: Result {
        let shots = allShots
        let selection = ShotSelection.select(shots, filter: applied, now: now())
        let profiles = ClubAnalysis.profiles(selection.shots, filter: applied, bagOrder: canonicalOrder)
        var allClubs = applied
        allClubs.clubs = .all
        let everyClub = ClubAnalysis.profiles(ShotSelection.select(shots, filter: allClubs, now: now()).shots, filter: allClubs)
        let mixed = applied.conditions == .asRecorded && ClubGapping.hasMixedConditions(selection.shots)
        return Result(
            selection: selection, profiles: profiles,
            gap: ClubGapping.table(profiles, filter: applied, eligibleClubCount: everyClub.count, mixedConditions: mixed),
            points: Dispersion.points(selection.shots, filter: applied), mixedConditions: mixed, eligibleClubCount: everyClub.count
        )
    }

    /// Clubs that can be chosen: every club that has a shot (archived ones included), bag order first, then others by name.
    var clubOptions: [ClubSnapshot] {
        var latest: [UUID: Shot] = [:]
        for shot in allShots where (latest[shot.clubSnapshot.id]?.impactTimeUTC ?? .distantPast) <= shot.impactTimeUTC {
            latest[shot.clubSnapshot.id] = shot
        }
        let rank = Dictionary(uniqueKeysWithValues: bagOrder.enumerated().map { ($1, $0) })
        return latest.values.map(\.clubSnapshot).sorted { a, b in
            switch (rank[a.id], rank[b.id]) {
            case let (x?, y?): x < y
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        }
    }

    // MARK: filter editing (draft / apply / cancel / clear)

    func openFilter() {
        editor.cancel()
        showingFilter = true
    }

    @discardableResult
    func applyFilter() -> Bool {
        guard editor.apply() else { return false }
        persist()
        showingFilter = false
        return true
    }

    /// Changes one filter choice straight from a chip, as one atomic apply.
    func update(_ change: (inout AnalysisFilter) -> Void) {
        var f = editor.applied
        change(&f)
        guard f.canApply else { return }
        editor = AnalysisFilterEditor(applied: f)
        persist()
    }

    func cancelFilter() {
        editor.cancel()
        showingFilter = false
    }

    func clearDraft() {
        editor.clear()
    }

    /// Scope the analysis to one session (from a session's own screen) and keep every other choice.
    func focus(onSession id: UUID) {
        var f = editor.applied
        f.sessionIDs = [id]
        editor = AnalysisFilterEditor(applied: f)
        persist()
    }

    func clearSessionScope() {
        var f = editor.applied
        f.sessionIDs = nil
        editor = AnalysisFilterEditor(applied: f)
        persist()
    }

    /// A shot's comparison with its club's average under the active filter.
    func comparison(for shot: Shot, key: MetricKey) -> ShotComparison? {
        let r = result
        let profile = r.profiles.first { $0.clubID == shot.clubSnapshot.id }
        return ShotCompare.compare(shot, key: key, within: profile, selection: r.selection.shots, view: applied.conditions)
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        defaults.set(try? encoder.encode(editor.applied), forKey: Self.filterKey)
    }
}
