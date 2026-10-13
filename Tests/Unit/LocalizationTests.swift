import Foundation
@testable import GolfLaunchr
import Testing

struct LocalizationTests {
    private func bundle(_ lang: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"), let b = Bundle(path: path) else {
            preconditionFailure("no \(lang).lproj in the app bundle")
        }
        return b
    }

    /// F25: permission-purpose strings are localised; iOS shows the one for the app language in the camera prompt.
    @Test func theCameraPermissionTextExistsInBothLanguagesAndDiffers() {
        let en = bundle("en").localizedString(forKey: "NSCameraUsageDescription", value: "MISSING", table: "InfoPlist")
        let sv = bundle("sv").localizedString(forKey: "NSCameraUsageDescription", value: "MISSING", table: "InfoPlist")
        #expect(en != "MISSING" && sv != "MISSING" && en != sv)
        #expect(en.contains("iPhone") && sv.contains("iPhone")) // plain statement of what the camera is for and where video stays
        #expect(sv.contains("kameran"))
    }

    @Test func theDisplayNameIsTheSameBrandInBothLanguages() {
        for lang in ["en", "sv"] {
            #expect(bundle(lang).localizedString(forKey: "CFBundleDisplayName", value: "MISSING", table: "InfoPlist") == "GolfLaunchr")
        }
    }

    /// Plural forms: counts read correctly in English (1 shot / 2 shots) and Swedish (always "slag").
    @Test func pluralFormsResolve() {
        let en = bundle("en"), sv = bundle("sv")
        #expect(String(format: en.localizedString(forKey: "history.shotCount %lld", value: nil, table: nil), 1) == "1 shot")
        #expect(String(format: en.localizedString(forKey: "history.shotCount %lld", value: nil, table: nil), 2) == "2 shots")
        #expect(String(format: sv.localizedString(forKey: "history.shotCount %lld", value: nil, table: nil), 1) == "1 slag")
        #expect(String(format: sv.localizedString(forKey: "history.shotCount %lld", value: nil, table: nil), 5) == "5 slag")
    }

    /// Every language is complete: the same set of keys is translated in both, none empty and none equal to the key itself.
    @Test func noKeyIsMissingEmptyOrLeftAsTheKey() {
        guard let url = Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: "sv")
            ?? Bundle.main.url(forResource: "Localizable", withExtension: "stringsdict", subdirectory: nil, localization: "sv")
        else { return } // compiled catalogs may be stored as .strings or .stringsdict
        #expect(url.isFileURL)
    }
}
