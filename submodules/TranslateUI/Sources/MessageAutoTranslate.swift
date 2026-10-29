import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences

/// 消息级自动翻译：使用 Harbor 引擎链（AutoTranslator）将非目标语言消息写入 TranslationMessageAttribute
/// 气泡层已有逻辑会在 attribute.toLang 匹配时展示译文。

public enum MessageAutoTranslate {
    
    /// 将 messageIds 对应文本经 AutoTranslator 翻译后写回本地消息属性
    public static func translateAndApply(
        context: AccountContext,
        messageIds: [EngineMessage.Id],
        toLang: String
    ) -> Signal<Never, NoError> {
        return context.account.postbox.transaction { transaction -> [(EngineMessage.Id, String)] in
            var pairs: [(EngineMessage.Id, String)] = []
            var seen = Set<EngineMessage.Id>()
            for messageId in messageIds {
                guard let message = transaction.getMessage(messageId) else { continue }
                if message.author?.id == context.account.peerId { continue }
                if let existing = message.attributes.first(where: { $0 is TranslationMessageAttribute }) as? TranslationMessageAttribute,
                   existing.toLang == toLang, !existing.text.isEmpty {
                    continue
                }
                let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                if seen.contains(messageId) { continue }
                seen.insert(messageId)
                pairs.append((messageId, text))
            }
            return pairs
        }
        |> mapToSignal { pairs -> Signal<Never, NoError> in
            guard !pairs.isEmpty else {
                return .complete()
            }
            return Signal { subscriber in
                let task = Task {
                    // 同步设置到 AutoTranslator
                    await applySettingsIfNeeded(context: context)
                    
                    var results: [(EngineMessage.Id, String)] = []
                    for (id, text) in pairs {
                        let translated = await AutoTranslator.shared.translateIfNeeded(text)
                        if translated != text, !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            results.append((id, translated))
                        }
                    }
                    
                    if !results.isEmpty {
                        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                            let _ = context.account.postbox.transaction { transaction -> Void in
                                for (messageId, translatedText) in results {
                                    transaction.updateMessage(messageId, update: { currentMessage in
                                        let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                                        var attributes = currentMessage.attributes.filter { !($0 is TranslationMessageAttribute) }
                                        let updatedAttribute = TranslationMessageAttribute(
                                            text: translatedText,
                                            entities: [],
                                            additional: [],
                                            pollSolution: nil,
                                            toLang: toLang
                                        )
                                        attributes.append(updatedAttribute)
                                        return .update(StoreMessage(
                                            id: currentMessage.id,
                                            customStableId: nil,
                                            globallyUniqueId: currentMessage.globallyUniqueId,
                                            groupingKey: currentMessage.groupingKey,
                                            threadId: currentMessage.threadId,
                                            timestamp: currentMessage.timestamp,
                                            flags: StoreMessageFlags(currentMessage.flags),
                                            tags: currentMessage.tags,
                                            globalTags: currentMessage.globalTags,
                                            localTags: currentMessage.localTags,
                                            forwardInfo: storeForwardInfo,
                                            authorId: currentMessage.author?.id,
                                            text: currentMessage.text,
                                            attributes: attributes,
                                            media: currentMessage.media
                                        ))
                                    })
                                }
                            }.start(completed: {
                                cont.resume()
                            })
                        }
                    }
                    subscriber.putCompletion()
                }
                return ActionDisposable {
                    task.cancel()
                }
            }
        }
    }
    
    private static func applySettingsIfNeeded(context: AccountContext) async {
        let settings: TranslationSettings = await withCheckedContinuation { cont in
            let _ = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
            |> take(1)
            |> map { sharedData -> TranslationSettings in
                sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self)
                    ?? TranslationSettings.defaultSettings
            }).start(next: { s in
                cont.resume(returning: s)
            })
        }
        AutoTranslateSettingsBridge.apply(
            autoTranslateNonTarget: settings.autoTranslateNonTarget,
            targetLanguageCode: settings.autoTranslateTargetLanguage,
            engineChainRaw: settings.autoTranslateEngineChain,
            deepLKey: settings.autoTranslateDeepLKey,
            microsoftKey: settings.autoTranslateMicrosoftKey,
            microsoftRegion: settings.autoTranslateMicrosoftRegion
        )
    }
    
    /// 目标语言 code：设置里的 zhHans → 气泡匹配用的 toLang（如 zh）
    public static func bubbleToLang(from settings: TranslationSettings) -> String {
        switch settings.autoTranslateTargetLanguage {
        case "zhHans": return "zh"
        case "zhHant": return "zh-hant"
        default: return settings.autoTranslateTargetLanguage
        }
    }
}
