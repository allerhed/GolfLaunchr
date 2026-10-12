import Domain
import SwiftUI

extension ClubCategory {
    var titleKey: LocalizedStringKey {
        switch self {
        case .driver: "club.category.driver"
        case .wood: "club.category.wood"
        case .hybrid: "club.category.hybrid"
        case .iron: "club.category.iron"
        case .wedge: "club.category.wedge"
        case .putter: "club.category.putter"
        case .other: "club.category.other"
        }
    }
}

extension ClubValidationError {
    var messageKey: LocalizedStringKey {
        switch self {
        case .emptyName: "clubEdit.error.emptyName"
        case .nameTooLong: "clubEdit.error.nameTooLong"
        case .duplicateActiveName: "clubEdit.error.duplicateName"
        case .loftNotFinite: "clubEdit.error.loftNotFinite"
        case .loftOutOfRange: "clubEdit.error.loftOutOfRange"
        case .unknownClub, .archived, .notArchived: "bag.saveError"
        }
    }
}

extension BagStoreError {
    var messageKey: LocalizedStringKey {
        switch self {
        case let .validation(error): error.messageKey
        case .saveFailed: "bag.saveError"
        }
    }
}

/// Seed club names are localised once, when the bag is first created, and are then ordinary user data.
enum BagSeedNames {
    private static let names: [SeedClub: LocalizedStringResource] = [
        .driver: LocalizedStringResource("seed.club.driver", comment: "Seeded club name: driver"),
        .wood3: LocalizedStringResource("seed.club.wood3", comment: "Seeded club name: 3 wood"),
        .hybrid4: LocalizedStringResource("seed.club.hybrid4", comment: "Seeded club name: 4 hybrid"),
        .iron5: LocalizedStringResource("seed.club.iron5", comment: "Seeded club name: 5 iron"),
        .iron6: LocalizedStringResource("seed.club.iron6", comment: "Seeded club name: 6 iron"),
        .iron7: LocalizedStringResource("seed.club.iron7", comment: "Seeded club name: 7 iron"),
        .iron8: LocalizedStringResource("seed.club.iron8", comment: "Seeded club name: 8 iron"),
        .iron9: LocalizedStringResource("seed.club.iron9", comment: "Seeded club name: 9 iron"),
        .pitchingWedge: LocalizedStringResource("seed.club.pw", comment: "Seeded club name: pitching wedge"),
        .gapWedge: LocalizedStringResource("seed.club.gw", comment: "Seeded club name: gap wedge"),
        .sandWedge: LocalizedStringResource("seed.club.sw", comment: "Seeded club name: sand wedge"),
        .lobWedge: LocalizedStringResource("seed.club.lw", comment: "Seeded club name: lob wedge"),
        .putter: LocalizedStringResource("seed.club.putter", comment: "Seeded club name: putter"),
    ]

    static func localized(_ seed: SeedClub) -> String {
        names[seed].map { String(localized: $0) } ?? "\(seed)"
    }
}
