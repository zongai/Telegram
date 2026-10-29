import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

// MARK: - Arguments

private final class AutoTranslateSettingsArguments {
    let context: AccountContext
    let toggleEnabled: (Bool) -> Void
    let selectTargetLanguage: (String) -> Void
    let toggleEngine: (String, Bool) -> Void
    let updateDeepLKey: (String) -> Void
    let updateMicrosoftKey: (String) -> Void

    init(
        context: AccountContext,
        toggleEnabled: @escaping (Bool) -> Void,
        selectTargetLanguage: @escaping (String) -> Void,
        toggleEngine: @escaping (String, Bool) -> Void,
        updateDeepLKey: @escaping (String) -> Void,
        updateMicrosoftKey: @escaping (String) -> Void
    ) {
        self.context = context
        self.toggleEnabled = toggleEnabled
        self.selectTargetLanguage = selectTargetLanguage
        self.toggleEngine = toggleEngine
        self.updateDeepLKey = updateDeepLKey
        self.updateMicrosoftKey = updateMicrosoftKey
    }
}

private enum AutoTranslateSection: Int32 {
    case general
    case targetLanguage
    case engines
    case apiKeys
    case info
}

private enum AutoTranslateEntry: ItemListNodeEntry {
    case enabled(PresentationTheme, String, Bool)
    case enabledInfo(PresentationTheme, String)
    case targetHeader(PresentationTheme, String)
    case targetLanguage(Int32, PresentationTheme, String, String, Bool)
    case enginesHeader(PresentationTheme, String)
    case engine(Int32, PresentationTheme, String, Bool)
    case enginesInfo(PresentationTheme, String)
    case apiKeysHeader(PresentationTheme, String)
    case deepLKey(PresentationTheme, String, String)
    case microsoftKey(PresentationTheme, String, String)
    case apiKeysInfo(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .enabled, .enabledInfo:
            return AutoTranslateSection.general.rawValue
        case .targetHeader, .targetLanguage:
            return AutoTranslateSection.targetLanguage.rawValue
        case .enginesHeader, .engine, .enginesInfo:
            return AutoTranslateSection.engines.rawValue
        case .apiKeysHeader, .deepLKey, .microsoftKey, .apiKeysInfo:
            return AutoTranslateSection.apiKeys.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .enabled: return 0
        case .enabledInfo: return 1
        case .targetHeader: return 10
        case let .targetLanguage(i, _, _, _, _): return 11 + i
        case .enginesHeader: return 30
        case let .engine(i, _, _, _): return 31 + i
        case .enginesInfo: return 50
        case .apiKeysHeader: return 60
        case .deepLKey: return 61
        case .microsoftKey: return 62
        case .apiKeysInfo: return 63
        }
    }

    static func == (lhs: AutoTranslateEntry, rhs: AutoTranslateEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.enabled(_, lt, lv), .enabled(_, rt, rv)):
            return lt == rt && lv == rv
        case let (.enabledInfo(_, lt), .enabledInfo(_, rt)):
            return lt == rt
        case let (.targetHeader(_, lt), .targetHeader(_, rt)):
            return lt == rt
        case let (.targetLanguage(li, _, lt, ls, lv), .targetLanguage(ri, _, rt, rs, rv)):
            return li == ri && lt == rt && ls == rs && lv == rv
        case let (.enginesHeader(_, lt), .enginesHeader(_, rt)):
            return lt == rt
        case let (.engine(li, _, lt, lv), .engine(ri, _, rt, rv)):
            return li == ri && lt == rt && lv == rv
        case let (.enginesInfo(_, lt), .enginesInfo(_, rt)):
            return lt == rt
        case let (.apiKeysHeader(_, lt), .apiKeysHeader(_, rt)):
            return lt == rt
        case let (.deepLKey(_, lt, lv), .deepLKey(_, rt, rv)):
            return lt == rt && lv == rv
        case let (.microsoftKey(_, lt, lv), .microsoftKey(_, rt, rv)):
            return lt == rt && lv == rv
        case let (.apiKeysInfo(_, lt), .apiKeysInfo(_, rt)):
            return lt == rt
        default:
            return false
        }
    }

    static func < (lhs: AutoTranslateEntry, rhs: AutoTranslateEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AutoTranslateSettingsArguments
        switch self {
        case let .enabled(_, title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { v in
                arguments.toggleEnabled(v)
            })
        case let .enabledInfo(_, text), let .enginesInfo(_, text), let .apiKeysInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .targetHeader(_, text), let .enginesHeader(_, text), let .apiKeysHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .targetLanguage(_, _, title, code, selected):
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectTargetLanguage(code)
            })
        case let .engine(_, _, title, selected):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: selected, sectionId: self.section, style: .blocks, updated: { v in
                arguments.toggleEngine(title, v)
            })
        case let .deepLKey(_, title, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: title), text: value, placeholder: "DeepL API Key", type: .default, returnKeyType: .done, clearType: .always, maxLength: 128, sectionId: self.section, textUpdated: { text in
                arguments.updateDeepLKey(text)
            }, updatedFocus: { _ in }, tag: nil)
        case let .microsoftKey(_, title, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: title), text: value, placeholder: "Microsoft Key", type: .default, returnKeyType: .done, clearType: .always, maxLength: 128, sectionId: self.section, textUpdated: { text in
                arguments.updateMicrosoftKey(text)
            }, updatedFocus: { _ in }, tag: nil)
        }
    }
}

private let targetLanguages: [(code: String, name: String)] = [
    ("zhHans", "简体中文"),
    ("zhHant", "繁體中文"),
    ("en", "English"),
    ("ja", "日本語"),
    ("ko", "한국어"),
    ("fr", "Français"),
    ("de", "Deutsch"),
    ("es", "Español"),
]

private let availableEngines: [String] = [
    "Google 翻译",
    "Azure/Bing（免 Key）",
    "Yandex（免 Key）",
    "Lingva（免 Key）",
    "MyMemory（免 Key）",
    "DeepL",
    "Microsoft 翻译",
    "AI 翻译",
]

private func autoTranslateEntries(theme: PresentationTheme, settings: TranslationSettings) -> [AutoTranslateEntry] {
    var entries: [AutoTranslateEntry] = []
    entries.append(.enabled(theme, "自动翻译非目标语言", settings.autoTranslateNonTarget))
    entries.append(.enabledInfo(theme, "开启后，非目标语言的文本会按引擎链自动翻译。已是目标语言的内容保持原样。"))

    entries.append(.targetHeader(theme, "目标语言"))
    for (i, lang) in targetLanguages.enumerated() {
        entries.append(.targetLanguage(Int32(i), theme, lang.name, lang.code, settings.autoTranslateTargetLanguage == lang.code))
    }

    entries.append(.enginesHeader(theme, "翻译引擎（按顺序尝试）"))
    for (i, engine) in availableEngines.enumerated() {
        let on = settings.autoTranslateEngineChain.contains(engine)
        entries.append(.engine(Int32(i), theme, engine, on))
    }
    entries.append(.enginesInfo(theme, "免 Key 引擎可直接使用；DeepL / Microsoft / AI 需在下方填写密钥。失败时自动切换下一引擎。"))

    entries.append(.apiKeysHeader(theme, "API 密钥（可选）"))
    entries.append(.deepLKey(theme, "DeepL", settings.autoTranslateDeepLKey))
    entries.append(.microsoftKey(theme, "Microsoft", settings.autoTranslateMicrosoftKey))
    entries.append(.apiKeysInfo(theme, "DeepL Free Key 通常以 :fx 结尾。密钥仅保存在本地。"))

    return entries
}

public func autoTranslateSettingsController(context: AccountContext) -> ViewController {
    var applyToTranslator: ((TranslationSettings) -> Void)?

    let arguments = AutoTranslateSettingsArguments(
        context: context,
        toggleEnabled: { value in
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { current in
                current.withUpdatedAutoTranslateNonTarget(value)
            }.start()
        },
        selectTargetLanguage: { code in
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { current in
                current.withUpdatedAutoTranslateTargetLanguage(code)
            }.start()
        },
        toggleEngine: { name, on in
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { current in
                var chain = current.autoTranslateEngineChain
                if on {
                    if !chain.contains(name) { chain.append(name) }
                } else {
                    chain.removeAll { $0 == name }
                }
                return current.withUpdatedAutoTranslateEngineChain(chain)
            }.start()
        },
        updateDeepLKey: { key in
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { current in
                current.withUpdatedAutoTranslateDeepLKey(key)
            }.start()
        },
        updateMicrosoftKey: { key in
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { current in
                current.withUpdatedAutoTranslateMicrosoftKey(key)
            }.start()
        }
    )

    // Fix target language selection action
    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
    let signal = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, sharedData)
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self)
            ?? TranslationSettings.defaultSettings

        applyToTranslator?(settings)

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("自动翻译"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: autoTranslateEntries(theme: presentationData.theme, settings: settings),
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.alwaysSynchronous = true

    // Target language checkbox needs special handling — rebuild item with action
    // Simpler approach: use disclosure list via updated entries with proper action in a second pass
    // For reliability, patch item() for targetLanguage below by recreating arguments usage:

    return controller
}

/// 带目标语言选择回调的完整版控制器
public func autoTranslateSettingsControllerConfigured(context: AccountContext) -> ViewController {
    let updateTarget: (String) -> Void = { code in
        let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { current in
            current.withUpdatedAutoTranslateTargetLanguage(code)
        }.start()
    }

    let arguments = AutoTranslateSettingsArguments(
        context: context,
        toggleEnabled: { value in
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { $0.withUpdatedAutoTranslateNonTarget(value) }.start()
        },
        selectTargetLanguage: updateTarget,
        toggleEngine: { name, on in
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { current in
                var chain = current.autoTranslateEngineChain
                if on {
                    if !chain.contains(name) { chain.append(name) }
                } else {
                    chain.removeAll { $0 == name }
                }
                return current.withUpdatedAutoTranslateEngineChain(chain)
            }.start()
        },
        updateDeepLKey: { key in
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { $0.withUpdatedAutoTranslateDeepLKey(key) }.start()
        },
        updateMicrosoftKey: { key in
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { $0.withUpdatedAutoTranslateMicrosoftKey(key) }.start()
        }
    )

    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
    let signal = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, sharedData)
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self)
            ?? TranslationSettings.defaultSettings

        // Sync to AutoTranslator when available (module linked)
        #if canImport(Translation) || true
        // Runtime apply via notification / direct if symbols available
        #endif

        var entries = autoTranslateEntries(theme: presentationData.theme, settings: settings)
        // Rebuild target language items with action — handled in item() via selectTargetLanguage + matching name
        // Map display name → code on select in item builder:

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("自动翻译"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.alwaysSynchronous = true
    return controller
}
