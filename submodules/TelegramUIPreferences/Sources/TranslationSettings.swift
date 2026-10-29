import Foundation
import TelegramCore
import SwiftSignalKit

public struct TranslationSettings: Codable, Equatable {
    public var showTranslate: Bool
    public var translateChats: Bool
    public var ignoredLanguages: [String]?
    
    // MARK: - Auto-translate (Harbor Translation module)
    /// 自动翻译非目标语言
    public var autoTranslateNonTarget: Bool
    /// 目标语言：zhHans / zhHant / en / ja / ko / fr / de / es
    public var autoTranslateTargetLanguage: String
    /// 引擎链原始值，如 ["Google 翻译", "Azure/Bing（免 Key）"]
    public var autoTranslateEngineChain: [String]
    public var autoTranslateDeepLKey: String
    public var autoTranslateMicrosoftKey: String
    public var autoTranslateMicrosoftRegion: String
    
    public static var defaultSettings: TranslationSettings {
        return TranslationSettings(
            showTranslate: false,
            translateChats: true,
            ignoredLanguages: nil,
            autoTranslateNonTarget: true,
            autoTranslateTargetLanguage: "zhHans",
            autoTranslateEngineChain: ["Google 翻译", "Azure/Bing（免 Key）", "Yandex（免 Key）", "Lingva（免 Key）", "MyMemory（免 Key）"],
            autoTranslateDeepLKey: "",
            autoTranslateMicrosoftKey: "",
            autoTranslateMicrosoftRegion: ""
        )
    }
    
    init(
        showTranslate: Bool,
        translateChats: Bool,
        ignoredLanguages: [String]?,
        autoTranslateNonTarget: Bool = true,
        autoTranslateTargetLanguage: String = "zhHans",
        autoTranslateEngineChain: [String] = ["Google 翻译", "Azure/Bing（免 Key）", "Yandex（免 Key）", "Lingva（免 Key）", "MyMemory（免 Key）"],
        autoTranslateDeepLKey: String = "",
        autoTranslateMicrosoftKey: String = "",
        autoTranslateMicrosoftRegion: String = ""
    ) {
        self.showTranslate = showTranslate
        self.translateChats = translateChats
        self.ignoredLanguages = ignoredLanguages
        self.autoTranslateNonTarget = autoTranslateNonTarget
        self.autoTranslateTargetLanguage = autoTranslateTargetLanguage
        self.autoTranslateEngineChain = autoTranslateEngineChain
        self.autoTranslateDeepLKey = autoTranslateDeepLKey
        self.autoTranslateMicrosoftKey = autoTranslateMicrosoftKey
        self.autoTranslateMicrosoftRegion = autoTranslateMicrosoftRegion
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.showTranslate = try container.decodeIfPresent(Bool.self, forKey: "showTranslate") ?? false
        self.translateChats = try container.decodeIfPresent(Bool.self, forKey: "translateChats") ?? true
        self.ignoredLanguages = try container.decodeIfPresent([String].self, forKey: "ignoredLanguages")
        self.autoTranslateNonTarget = try container.decodeIfPresent(Bool.self, forKey: "autoTranslateNonTarget") ?? true
        self.autoTranslateTargetLanguage = try container.decodeIfPresent(String.self, forKey: "autoTranslateTargetLanguage") ?? "zhHans"
        self.autoTranslateEngineChain = try container.decodeIfPresent([String].self, forKey: "autoTranslateEngineChain")
            ?? ["Google 翻译", "Azure/Bing（免 Key）", "Yandex（免 Key）", "Lingva（免 Key）", "MyMemory（免 Key）"]
        self.autoTranslateDeepLKey = try container.decodeIfPresent(String.self, forKey: "autoTranslateDeepLKey") ?? ""
        self.autoTranslateMicrosoftKey = try container.decodeIfPresent(String.self, forKey: "autoTranslateMicrosoftKey") ?? ""
        self.autoTranslateMicrosoftRegion = try container.decodeIfPresent(String.self, forKey: "autoTranslateMicrosoftRegion") ?? ""
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.showTranslate, forKey: "showTranslate")
        try container.encode(self.translateChats, forKey: "translateChats")
        try container.encodeIfPresent(self.ignoredLanguages, forKey: "ignoredLanguages")
        try container.encode(self.autoTranslateNonTarget, forKey: "autoTranslateNonTarget")
        try container.encode(self.autoTranslateTargetLanguage, forKey: "autoTranslateTargetLanguage")
        try container.encode(self.autoTranslateEngineChain, forKey: "autoTranslateEngineChain")
        try container.encode(self.autoTranslateDeepLKey, forKey: "autoTranslateDeepLKey")
        try container.encode(self.autoTranslateMicrosoftKey, forKey: "autoTranslateMicrosoftKey")
        try container.encode(self.autoTranslateMicrosoftRegion, forKey: "autoTranslateMicrosoftRegion")
    }
    
    public static func ==(lhs: TranslationSettings, rhs: TranslationSettings) -> Bool {
        return lhs.showTranslate == rhs.showTranslate
            && lhs.translateChats == rhs.translateChats
            && lhs.ignoredLanguages == rhs.ignoredLanguages
            && lhs.autoTranslateNonTarget == rhs.autoTranslateNonTarget
            && lhs.autoTranslateTargetLanguage == rhs.autoTranslateTargetLanguage
            && lhs.autoTranslateEngineChain == rhs.autoTranslateEngineChain
            && lhs.autoTranslateDeepLKey == rhs.autoTranslateDeepLKey
            && lhs.autoTranslateMicrosoftKey == rhs.autoTranslateMicrosoftKey
            && lhs.autoTranslateMicrosoftRegion == rhs.autoTranslateMicrosoftRegion
    }
    
    public func withUpdatedShowTranslate(_ showTranslate: Bool) -> TranslationSettings {
        var s = self
        s.showTranslate = showTranslate
        return s
    }
    
    public func withUpdatedTranslateChats(_ translateChats: Bool) -> TranslationSettings {
        var s = self
        s.translateChats = translateChats
        return s
    }
    
    public func withUpdatedIgnoredLanguages(_ ignoredLanguages: [String]?) -> TranslationSettings {
        var s = self
        s.ignoredLanguages = ignoredLanguages
        return s
    }
    
    public func withUpdatedAutoTranslateNonTarget(_ value: Bool) -> TranslationSettings {
        var s = self
        s.autoTranslateNonTarget = value
        return s
    }
    
    public func withUpdatedAutoTranslateTargetLanguage(_ value: String) -> TranslationSettings {
        var s = self
        s.autoTranslateTargetLanguage = value
        return s
    }
    
    public func withUpdatedAutoTranslateEngineChain(_ value: [String]) -> TranslationSettings {
        var s = self
        s.autoTranslateEngineChain = value
        return s
    }
    
    public func withUpdatedAutoTranslateDeepLKey(_ value: String) -> TranslationSettings {
        var s = self
        s.autoTranslateDeepLKey = value
        return s
    }
    
    public func withUpdatedAutoTranslateMicrosoftKey(_ value: String) -> TranslationSettings {
        var s = self
        s.autoTranslateMicrosoftKey = value
        return s
    }
    
    public func withUpdatedAutoTranslateMicrosoftRegion(_ value: String) -> TranslationSettings {
        var s = self
        s.autoTranslateMicrosoftRegion = value
        return s
    }
}

public func updateTranslationSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (TranslationSettings) -> TranslationSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.translationSettings, { entry in
            let currentSettings: TranslationSettings
            if let entry = entry?.get(TranslationSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = TranslationSettings.defaultSettings
            }
            return SharedPreferencesEntry(f(currentSettings))
        })
    }
}
