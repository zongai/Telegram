import Foundation

/// 将 Telegram `TranslationSettings` 同步到 `AutoTranslator.shared`
/// 在设置变更或 App 启动后调用
public enum AutoTranslateSettingsBridge {
    public static func apply(
        autoTranslateNonTarget: Bool,
        targetLanguageCode: String,
        engineChainRaw: [String],
        deepLKey: String,
        microsoftKey: String,
        microsoftRegion: String
    ) {
        let translator = AutoTranslator.shared
        if let lang = AppLanguage(rawValue: targetLanguageCode) {
            translator.targetLanguage = lang
        }
        let engines = engineChainRaw.compactMap { TranslationEngine(rawValue: $0) }
        if !engines.isEmpty {
            translator.engineChain = engines
        }
        translator.deepLAPIKey = deepLKey
        translator.microsoftAPIKey = microsoftKey
        translator.microsoftRegion = microsoftRegion
        // autoTranslateNonTarget 由调用方决定是否调用 translateIfNeeded
        _ = autoTranslateNonTarget
    }

    /// 对文本：若开启自动翻译则 translateIfNeeded，否则原样返回
    public static func translateIfEnabled(_ text: String, enabled: Bool) async -> String {
        guard enabled else { return text }
        return await AutoTranslator.shared.translateIfNeeded(text)
    }
}
