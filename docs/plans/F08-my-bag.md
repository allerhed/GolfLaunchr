# F08 My Bag: club management (plan)

Status: planned 2026-10-11. Nothing implemented. Spec: `docs/spec/features/F08.md`, Club entity in `06-data-model.md`, test T08 in `08-tests-and-gates.md`.

## 1. Goal, scope, dependencies
Goal: every club has a stable UUID identity. The golfer can create, edit, reorder, archive and restore clubs, and gets an editable seeded bag on first launch. A value `ClubSnapshot` is what shots and sessions will copy.
- **Out of scope:** per-club carry, shot counts, dispersion and Club profile pane (mockups 09/15 show these, but they belong to F10/F10a). The "Map this club" CTA belongs to F09. Shots and sessions (F04/F20). Versioned loft recalculation of existing shots: F08 only records `loftRevision` so F06/F20 can do it later. Final tab or sidebar navigation (F22, 13-ui-direction).
- **Depends on:** nothing that is built yet. F20 (WP04) owns the persistence strategy, so F08 hides storage behind a protocol that F20 can re-implement. Later work depends on F08: F09 mapping, F10a gapping (`Analytics.ClubDistances.clubID` is a `String`; pass `club.id.uuidString`, do not change Analytics in F08).

## 2. Design
**Domain package (pure, `swift test`):**
```swift
public enum ClubCategory: String, Codable, Sendable, CaseIterable { case driver, wood, hybrid, iron, wedge, putter, other }
public struct Club: Identifiable, Codable, Sendable, Equatable {
  public let id: UUID                 // immutable
  public var name: String             // spec "label"; user-authored, never auto-translated
  public var category: ClubCategory
  public var loftRad: Double?         // nil = not set; never a guessed stock loft
  public var loftRevision: Int        // +1 on every loft change (future-estimation input version)
  public var brand: String?; public var model: String?
  public var sortOrder: Int
  public var archivedAt: Date?        // UTC; nil = active
}
public struct ClubSnapshot: Codable, Sendable, Equatable { public let id: UUID; public let name: String; public let loftRad: Double?; public let loftRevision: Int }
public enum ClubValidationError: Error, Equatable { case emptyName, nameTooLong, duplicateActiveName, loftNotFinite, loftOutOfRange, unknownClub, archived }
public enum LoftRule { static let minDeg = 1.0, maxDeg = 70.0; static func validate(degrees: Double?) throws(ClubValidationError) -> Double? /* returns radians */ }
public struct Bag: Codable, Sendable, Equatable {        // value-type state machine, all mutations validated
  public private(set) var clubs: [Club]; public var seeded: Bool; public static let schemaVersion = 1
  public var active: [Club] { get }                      // archivedAt == nil, sorted by sortOrder
  public var archived: [Club] { get }
  public mutating func add(name:category:loftDegrees:brand:model:now:) throws(ClubValidationError) -> Club
  public mutating func update(_ id: UUID, name:category:loftDegrees:brand:model:) throws(ClubValidationError)
  public mutating func move(fromOffsets: IndexSet, toOffset: Int)   // active list only, renumbers sortOrder 0...
  public mutating func archive(_ id: UUID, now: Date) throws(ClubValidationError)
  public mutating func restore(_ id: UUID) throws(ClubValidationError)   // appended at end of active order
  public func snapshot(_ id: UUID) -> ClubSnapshot?      // also works for archived clubs (history)
  public static func seeded(names: (SeedClub) -> String) -> Bag
}
public enum SeedClub: CaseIterable { case driver, wood3, hybrid4, iron5, iron6, iron7, iron8, iron9, pitchingWedge, gapWedge, sandWedge, lobWedge, putter }
public protocol ClubRepository: Sendable { func load() async throws -> Bag?; func save(_ bag: Bag) async throws }
```
Rules: there is **no hard delete** in F08 (archive only), so clubs cannot become orphans. Name: trimmed; 1 to 40 characters; must be unique among active clubs (case- and diacritic-insensitive); duplicates against archived clubs are allowed. Duplicate lofts are always allowed. Seed: lofts are all nil, `seeded = true`, and the bag is seeded only when `load()` returns nil (never re-seeded after the user archives everything). Seed names are localized **once at seed time** and then stored as plain user data.

**Persistence package (new, `Packages/Persistence`, depends on Domain):** `actor FileClubRepository: ClubRepository` stores JSON `{schemaVersion, bag}` at `ApplicationSupport/GolfLaunchr/bag.json` (the URL is injected for tests). Writes are atomic (`Data.write(options: .atomic)`). An unknown or newer `schemaVersion` throws, and the file is never overwritten. A corrupt file throws `corrupt`; the app shows an error and does not re-seed over it. F20 may swap in SwiftData behind the same protocol.

**App (SwiftUI only):** `@MainActor @Observable final class BagStore` holds `bag`, `loadState`, `lastError`, and an injected `ClubRepository`. It applies each mutation to a copy and saves; the in-memory state is replaced only after the save succeeds. Views: `BagView` (List: active section, collapsible Archived section, + toolbar, EditButton reorder, swipe to Archive/Restore), `ClubEditView` (Form: name, category picker, loft in degrees with a localized decimal field, brand, model; Save disabled with an inline error when invalid). Entry point: a "My Bag" button on `HomeView` inside a `NavigationStack` (temporary until F22 navigation). UI tests pass the launch argument `-uiTestBagFile <tmp path>` to get a fresh store. This is test-only plumbing, not demo data.

Concurrency: Domain types are `Sendable` values, the repository is an actor, and the store is `@MainActor`. No `try!` or force-unwraps.

## 3. Tasks (one Sonnet session each, in order)
1. **Domain model:** `Packages/Domain/Sources/Domain/Club.swift`, `Bag.swift`, `LoftRule.swift`, `SeedClub.swift`; tests in `Tests/DomainTests/BagTests.swift` and `LoftRuleTests.swift`.
2. **Persistence package:** `Packages/Persistence/{Package.swift, Sources/Persistence/FileClubRepository.swift, Tests/PersistenceTests/FileClubRepositoryTests.swift}`; add to `project.yml` packages and app dependencies; run `xcodegen generate`.
3. **App store and screens:** `App/Bag/BagStore.swift`, `App/Bag/BagView.swift`, `App/Bag/ClubEditView.swift`, modify `App/GolfLaunchrApp.swift` and `App/HomeView.swift`; add keys to `App/Localizable.xcstrings`; unit tests `Tests/Unit/BagStoreTests.swift` (with an in-memory/failing fake repository).
4. **UI tests:** `Tests/UI/BagUITests.swift` (en and sv, portrait and landscape), then `scripts/verify.sh --ui`, simulator screenshots compared with mockups 09/15 (layout only; the stats are out of scope).

## 4. Test cases (U = unit/package, A = app unit, UI = XCUITest, D = device-only NOT RUN)
- U1 Seed: 13 clubs, all `loftRad == nil`, at least 4 wedge-category clubs, unique IDs, sortOrder 0..12, `seeded == true`.
- U2 Loft: 1.0 and 70.0 degrees are accepted (boundaries); 0.99, 70.01, 0, -5, 90 give `loftOutOfRange`; NaN, +inf, -inf give `loftNotFinite`; nil is accepted and stays nil; 56 degrees round-trips to radians within 1e-12.
- U3 Duplicate lofts: two clubs at 56 degrees are both accepted.
- U4 Name: "" and "   " give `emptyName`; 41 characters give `nameTooLong`; 40 are accepted; "  7 iron " is stored as "7 iron"; "7 IRON" next to an active "7 iron" gives `duplicateActiveName`; the same name next to an archived "7 iron" is accepted; "Jarn 7" vs "Järn 7" counts as a duplicate (diacritic-insensitive).
- U5 Rename: take a snapshot, rename the club, check the old snapshot still has the old name and `snapshot(id)` has the new name with the same ID (T08).
- U6 Loft edit: changing the loft increments `loftRevision`; editing only the name does not; setting the same loft does not; an old snapshot keeps the old loft and revision.
- U7 Archive: ID kept, `archivedAt` set, removed from `active`, `snapshot(id)` still resolves; archiving twice gives `archived`; restore puts it at the end of active; unknown UUID gives `unknownClub`; editing an archived club gives `archived`.
- U8 Reorder: moving index 0 to the end renumbers sortOrder contiguously; archived clubs are unaffected.
- U9 Bag Codable round-trip is equal, including nil optionals; there is no API that removes a club.
- U10 Repository: a missing file loads nil; save then load is equal; a corrupt file throws and is left unchanged; `schemaVersion` 99 throws and is not overwritten.
- A1 BagStore: when the repository fails on save, the in-memory bag is unchanged and `lastError` is set. First load with nil seeds and saves once; a second load does not re-seed.
- A2 Seed names in sv are taken from the catalog (for example "Järn 7"); after switching to en the stored names stay Swedish (user data).
- UI1 en: open My Bag, add "Test 7i" with loft "34", it appears last; edit the loft to "abc" and Save is disabled with the error shown.
- UI2 sv: loft "56,5" is accepted (comma decimal); "56.5" handling follows the locale formatter and is asserted as the formatter's actual behaviour.
- UI3 Archive via swipe: the club moves to Archived; restore brings it back.
- UI4 Rotate to landscape in the edit form: the typed name and the selected club are preserved.
- UI5 Accessibility: no truncation crash at the largest Dynamic Type size (launch arg `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`); every control has a label.
- D1 VoiceOver walkthrough on a physical device: NOT RUN unless done manually.

## 5. UI notes
Mockups: `09_my_bag_portrait.png`, `15_my_bag_landscape.png` (inspiration only; no club images, use SF Symbols or nothing).
Identifiers: `home.openBag`, `bag.list`, `bag.add`, `bag.row.<uuid>`, `bag.archivedSection`, `bag.row.archive`, `bag.row.restore`, `clubEdit.name`, `clubEdit.category`, `clubEdit.loft`, `clubEdit.brand`, `clubEdit.model`, `clubEdit.save`, `clubEdit.error`.
New keys (en and sv, each with a comment): `home.openBag`, `bag.title`, `bag.add`, `bag.archived`, `bag.archive`, `bag.restore`, `bag.empty`, `bag.loadError`, `clubEdit.title.new`, `clubEdit.title.edit`, `clubEdit.name`, `clubEdit.category`, `clubEdit.loft`, `clubEdit.loft.hint` ("Optional, 1–70°"), `clubEdit.brand`, `clubEdit.model`, `clubEdit.save`, `clubEdit.error.{emptyName,nameTooLong,duplicateName,loftNotFinite,loftOutOfRange}`, `club.category.{driver,wood,hybrid,iron,wedge,putter,other}`, `seed.club.{driver,wood3,hybrid4,iron5,iron6,iron7,iron8,iron9,pw,gw,sw,lw,putter}`. Swedish golf terms go to `l10n-reviewer` (F25 glossary).

## 6. Rubber duck (how this could be wrong, and the check)
1. "No guessed stock loft" is violated if the seed fills lofts. Check: U1 asserts every seeded loft is nil.
2. "Cannot orphan shots" is violated by any delete path. Check: U9 plus a grep for `remove`/`delete` on `clubs` in Domain/App during QA.
3. "Updating loft affects future estimation only": snapshots must be values. Check: U5/U6 mutate after taking a snapshot.
4. The 1–70° range could reject a real club (a putter at 0–4°, or an extreme wedge). Check: the range is documented as a decision; a putter at 0° is rejected by design. Ask the user if this matters (see Q2).
5. Seed names could be re-translated on a locale switch, which would rewrite user data. Check: A2.
6. A save failure could leave the UI showing unsaved data as saved. Check: A1.
7. The sv decimal comma and rotation state. Check: UI2 and UI4 on the simulator; capture is unaffected.

## 7. Open questions (non-blocking; the plan proceeds with the stated defaults)
- Q1 Contract: `06-data-model.md` lists Club as "category, label, optional loftRad, archivedAt", but F08 also requires brand/model and sort order (and this plan adds `loftRevision`). Approve extending the Club contract (the planner then edits 06 and records it in `docs/DECISIONS.md`)? Until then the code uses `name` (= label) and treats the extra fields as additive optional fields.
- Q2 Loft range 1–70 degrees, putter loft optional. OK?
