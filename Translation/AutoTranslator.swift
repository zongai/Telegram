import Foundation

/// 自动翻译：非目标语言内容 → 目标语言
/// 参考 Harbor (feature/epub-opds) 的翻译接口与引擎链
public final class AutoTranslator: @unchecked Sendable {
    public static let shared = AutoTranslator()

    /// 目标语言（默认简体中文）
    public var targetLanguage: AppLanguage = .zhHans

    /// 引擎优先级链（空则使用全部免费引擎）
    public var engineChain: [TranslationEngine] = [
        .google, .azure, .yandex, .lingva, .mymemory
    ]

    /// DeepL / Microsoft / AI 等需要 Key 时由外部注入
    public var deepLAPIKey: String = ""
    public var microsoftAPIKey: String = ""
    public var microsoftRegion: String = ""
    public var aiProvider: AIProvider?
    public var aiAPIKey: String = ""
    public var translationPrompt: String = """
你是专业译者。将下面内容翻译成{{lang}}。
要求：只输出译文，不要前言或注释；忠实原意；保持段落与换行。
{{text}}
"""

    private let coordinator = TranslationCoordinator()
    private let lock = NSLock()

    public init() {}

    // MARK: - Public API

    /// 若文本已是目标语言则原样返回，否则按引擎链自动翻译
    public func translateIfNeeded(_ text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }
        if looksLikeTargetLanguage(trimmed) {
            return text
        }
        do {
            return try await translate(trimmed)
        } catch {
            return text
        }
    }

    /// 强制翻译到目标语言（走引擎链 + 冷却 failover）
    public func translate(_ text: String) async throws -> String {
        let chain = coordinator.effectiveChain(configured: engineChain)
        var lastError: Error = TranslationError.noProvider

        for engine in chain {
            do {
                let out = try await translate(text: text, with: engine)
                let polished = TranslationPolish.polish(out, targetLang: targetLanguage)
                if !polished.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return polished
                }
            } catch {
                lastError = error
                // 简单限流：部分错误标记冷却
                if isRateLimitError(error) {
                    coordinator.markLimited(engine, minutes: 3)
                }
                continue
            }
        }
        throw lastError
    }

    /// 批量：非目标语言才译，保持顺序
    public func translateIfNeeded(_ texts: [String]) async -> [String] {
        await withTaskGroup(of: (Int, String).self) { group in
            for (i, t) in texts.enumerated() {
                group.addTask {
                    let r = await self.translateIfNeeded(t)
                    return (i, r)
                }
            }
            var results = texts
            for await (i, r) in group {
                results[i] = r
            }
            return results
        }
    }

    // MARK: - Engine dispatch

    private func translate(text: String, with engine: TranslationEngine) async throws -> String {
        // 缓存
        if let cached = TranslationCache.get(
            text: text,
            targetLang: targetLanguage,
            provider: engine.rawValue
        ) {
            return cached
        }

        let result: String
        switch engine {
        case .google:
            result = try await GoogleTranslate.translate(text: text, targetLang: targetLanguage.googleCode)
        case .mymemory:
            result = try await MyMemoryTranslate.translate(text: text, targetLang: targetLanguage.googleCode)
        case .lingva:
            result = try await LingvaTranslate.translate(text: text, targetLang: targetLanguage.shortCode)
        case .yandex:
            result = try await YandexTranslate.translate(text: text, targetLang: targetLanguage.shortCode)
        case .azure:
            result = try await AzureBingTranslate.translate(text: text, targetLang: targetLanguage.microsoftCode)
        case .microsoft:
            guard !microsoftAPIKey.isEmpty else { throw TranslationError.apiError("未配置 Microsoft API Key") }
            result = try await MicrosoftTranslate.translate(
                text: text,
                apiKey: microsoftAPIKey,
                region: microsoftRegion,
                targetLang: targetLanguage.microsoftCode
            )
        case .deepl:
            guard !deepLAPIKey.isEmpty else { throw TranslationError.apiError("未配置 DeepL API Key") }
            result = try await DeepLTranslate.translate(
                text: text,
                apiKey: deepLAPIKey,
                targetLang: targetLanguage.deeplCode
            )
        case .ai:
            guard let provider = aiProvider, !aiAPIKey.isEmpty else {
                throw TranslationError.apiError("未配置 AI 翻译提供商")
            }
            let prompt = translationPrompt
                .replacingOccurrences(of: "{{lang}}", with: targetLanguage.displayName)
                .replacingOccurrences(of: "{{text}}", with: text)
            result = try await AITranslate.translate(
                text: text,
                provider: provider,
                apiKey: aiAPIKey,
                promptTemplate: prompt
            )
        }

        TranslationCache.set(result, text: text, targetLang: targetLanguage, provider: engine.rawValue)
        return result
    }

    // MARK: - Language heuristic (no external detector)

    /// 粗略判断是否已是目标语言，避免无谓翻译
    public func looksLikeTargetLanguage(_ text: String) -> Bool {
        let sample = String(text.prefix(200))
        switch targetLanguage {
        case .zhHans, .zhHant:
            // 含有一定比例汉字则视为中文
            let han = sample.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
            return Double(han) / Double(max(sample.count, 1)) > 0.25
        case .ja:
            let kana = sample.unicodeScalars.filter {
                (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value)
            }.count
            return Double(kana) / Double(max(sample.count, 1)) > 0.2
        case .ko:
            let hangul = sample.unicodeScalars.filter { (0xAC00...0xD7AF).contains($0.value) }.count
            return Double(hangul) / Double(max(sample.count, 1)) > 0.2
        case .en, .fr, .de, .es:
            // 拉丁文为主且几乎无 CJK
            let cjk = sample.unicodeScalars.filter {
                (0x4E00...0x9FFF).contains($0.value)
                    || (0x3040...0x30FF).contains($0.value)
                    || (0xAC00...0xD7AF).contains($0.value)
            }.count
            return cjk == 0
        }
    }

    private func isRateLimitError(_ error: Error) -> Bool {
        let msg = (error as? LocalizedError)?.errorDescription?.lowercased() ?? error.localizedDescription.lowercased()
        return msg.contains("429") || msg.contains("rate") || msg.contains("quota") || msg.contains("limit")
    }
}
