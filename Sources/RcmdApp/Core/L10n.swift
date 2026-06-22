import Foundation

enum L10n {
    private static let fallbackLanguage = "en"
    private static let supportedLanguages = Set(["en", "ru", "de", "es", "fr", "it"])

    static func tr(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: Locale(identifier: selectedLanguage), arguments: arguments)
    }

    private static var localizedBundle: Bundle {
        guard
            let path = Bundle.module.path(forResource: selectedLanguage, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return Bundle.module
        }

        return bundle
    }

    private static var selectedLanguage: String {
        for preferredLanguage in preferredLanguages {
            let normalizedLanguage = preferredLanguage.replacingOccurrences(of: "_", with: "-").lowercased()
            let languageCode = normalizedLanguage.split(separator: "-").first.map(String.init) ?? normalizedLanguage

            if supportedLanguages.contains(normalizedLanguage) {
                return normalizedLanguage
            }

            if supportedLanguages.contains(languageCode) {
                return languageCode
            }
        }

        return fallbackLanguage
    }

    private static var preferredLanguages: [String] {
        if let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
           !languages.isEmpty {
            return languages
        }

        if let language = UserDefaults.standard.string(forKey: "AppleLanguages"),
           !language.isEmpty {
            return [language]
        }

        return Locale.preferredLanguages
    }
}
