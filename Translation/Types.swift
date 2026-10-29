import Foundation

// MARK: - AppLanguage (from Harbor)

public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case zhHans, zhHant, en, ja, ko, fr, de, es

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        }
    }

    /// Google Translate `tl`
    public var googleCode: String {
        switch self {
        case .zhHans: return "zh-CN"
        case .zhHant: return "zh-TW"
        case .en: return "en"
        case .ja: return "ja"
        case .ko: return "ko"
        case .fr: return "fr"
        case .de: return "de"
        case .es: return "es"
        }
    }

    /// Microsoft Translator `to`
    public var microsoftCode: String {
        switch self {
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        default: return googleCode
        }
    }

    /// DeepL `target_lang`
    public var deeplCode: String {
        switch self {
        case .zhHans, .zhHant: return "ZH"
        case .en: return "EN"
        case .ja: return "JA"
        case .ko: return "KO"
        case .fr: return "FR"
        case .de: return "DE"
        case .es: return "ES"
        }
    }

    /// Yandex / Lingva style short code
    public var shortCode: String {
        switch self {
        case .zhHans: return "zh"
        case .zhHant: return "zh-TW"
        default: return googleCode
        }
    }
}

// MARK: - TranslationEngine (from Harbor)

public enum TranslationEngine: String, CaseIterable, Codable, Sendable {
    case google = "Google 翻译"
    case mymemory = "MyMemory（免 Key）"
    case lingva = "Lingva（免 Key）"
    case yandex = "Yandex（免 Key）"
    case azure = "Azure/Bing（免 Key）"
    case microsoft = "Microsoft 翻译"
    case deepl = "DeepL"
    case ai = "AI 翻译"

    /// 无需 API Key 的引擎
    public var isFreeNoKey: Bool {
        switch self {
        case .google, .mymemory, .lingva, .yandex, .azure: return true
        default: return false
        }
    }
}

// MARK: - AIProvider (from Harbor)

public struct AIProvider: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var baseURL: String
    public var model: String
    public var models: [String]
    public var economyModel: String
    /// "openai" | "gemini"
    public var kind: String
    public var isDefaultSummary: Bool
    public var isDefaultTranslation: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        model: String,
        models: [String] = [],
        economyModel: String = "",
        kind: String = "openai",
        isDefaultSummary: Bool = false,
        isDefaultTranslation: Bool = false
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.model = model
        self.models = models.isEmpty ? [model] : models
        self.economyModel = economyModel.isEmpty ? model : economyModel
        self.kind = kind
        self.isDefaultSummary = isDefaultSummary
        self.isDefaultTranslation = isDefaultTranslation
    }
}

// MARK: - Minimal Article stub (for AISummary compatibility)

public struct Article: Sendable {
    public var title: String
    public var content: String
    public init(title: String = "", content: String) {
        self.title = title
        self.content = content
    }
}
