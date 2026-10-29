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

// MARK: - Main Content Filter Settings

private final class ContentFilterArguments {
    let toggleHideAds: (Bool) -> Void
    let toggleFilterEnabled: (Bool) -> Void
    let openBlacklist: () -> Void
    let openWhitelist: () -> Void
    
    init(toggleHideAds: @escaping (Bool) -> Void, toggleFilterEnabled: @escaping (Bool) -> Void, openBlacklist: @escaping () -> Void, openWhitelist: @escaping () -> Void) {
        self.toggleHideAds = toggleHideAds
        self.toggleFilterEnabled = toggleFilterEnabled
        self.openBlacklist = openBlacklist
        self.openWhitelist = openWhitelist
    }
}

private enum ContentFilterSection: Int32 {
    case ads = 0
    case keywords = 1
}

private enum ContentFilterEntry: ItemListNodeEntry {
    case hideAds(String, Bool)
    case hideAdsInfo(String)
    case filterEnabled(String, Bool)
    case blacklist(String, String)
    case whitelist(String, String)
    case keywordsInfo(String)
    
    var section: ItemListSectionId {
        switch self {
        case .hideAds, .hideAdsInfo: return ContentFilterSection.ads.rawValue
        case .filterEnabled, .blacklist, .whitelist, .keywordsInfo: return ContentFilterSection.keywords.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .hideAds: return 0
        case .hideAdsInfo: return 1
        case .filterEnabled: return 10
        case .blacklist: return 11
        case .whitelist: return 12
        case .keywordsInfo: return 13
        }
    }
    
    static func == (lhs: ContentFilterEntry, rhs: ContentFilterEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.hideAds(a, b), .hideAds(c, d)): return a == c && b == d
        case let (.hideAdsInfo(a), .hideAdsInfo(b)): return a == b
        case let (.filterEnabled(a, b), .filterEnabled(c, d)): return a == c && b == d
        case let (.blacklist(a, b), .blacklist(c, d)): return a == c && b == d
        case let (.whitelist(a, b), .whitelist(c, d)): return a == c && b == d
        case let (.keywordsInfo(a), .keywordsInfo(b)): return a == b
        default: return false
        }
    }
    
    static func < (lhs: ContentFilterEntry, rhs: ContentFilterEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ContentFilterArguments
        switch self {
        case let .hideAds(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: section, style: .blocks, updated: { v in
                arguments.toggleHideAds(v)
            })
        case let .hideAdsInfo(text), let .keywordsInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        case let .filterEnabled(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: section, style: .blocks, updated: { v in
                arguments.toggleFilterEnabled(v)
            })
        case let .blacklist(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: section, style: .blocks, action: {
                arguments.openBlacklist()
            })
        case let .whitelist(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: section, style: .blocks, action: {
                arguments.openWhitelist()
            })
        }
    }
}

private func contentFilterEntries(settings: ContentFilterSettings) -> [ContentFilterEntry] {
    var entries: [ContentFilterEntry] = []
    entries.append(.hideAds("自动隐藏广告", settings.hideAds))
    entries.append(.hideAdsInfo("开启后，聊天信息流中的赞助/广告消息将不再显示。"))
    entries.append(.filterEnabled("启用关键词过滤", settings.filterEnabled))
    let bl = settings.blacklist.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    let wl = settings.whitelist.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    entries.append(.blacklist("黑名单", bl.isEmpty ? "未设置" : "\(bl.count) 个词"))
    entries.append(.whitelist("白名单", wl.isEmpty ? "未设置" : "\(wl.count) 个词"))
    entries.append(.keywordsInfo("消息包含黑名单词语时自动隐藏；同时命中白名单则仍然显示。"))
    return entries
}

public func contentFilterSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = ContentFilterArguments(
        toggleHideAds: { value in
            let _ = updateContentFilterSettingsInteractively(accountManager: context.sharedContext.accountManager) {
                $0.withUpdatedHideAds(value)
            }.start()
        },
        toggleFilterEnabled: { value in
            let _ = updateContentFilterSettingsInteractively(accountManager: context.sharedContext.accountManager) {
                $0.withUpdatedFilterEnabled(value)
            }.start()
        },
        openBlacklist: {
            pushControllerImpl?(contentFilterKeywordListController(context: context, isBlacklist: true))
        },
        openWhitelist: {
            pushControllerImpl?(contentFilterKeywordListController(context: context, isBlacklist: false))
        }
    )
    
    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.contentFilterSettings])
    let signal = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, sharedData)
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.contentFilterSettings]?.get(ContentFilterSettings.self)
            ?? ContentFilterSettings.defaultSettings
        let state = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("内容过滤"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: contentFilterEntries(settings: settings),
            style: .blocks,
            animateChanges: true
        )
        return (state, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.alwaysSynchronous = true
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}

// MARK: - Keyword list (blacklist / whitelist)

private final class KeywordListArguments {
    let addWord: (String) -> Void
    let removeWord: (String) -> Void
    init(addWord: @escaping (String) -> Void, removeWord: @escaping (String) -> Void) {
        self.addWord = addWord
        self.removeWord = removeWord
    }
}

private enum KeywordListEntry: ItemListNodeEntry {
    case input(String)
    case word(Int32, String)
    case info(String)
    
    var section: ItemListSectionId {
        switch self {
        case .input: return 0
        case .word: return 1
        case .info: return 1
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .input: return -1
        case let .word(i, _): return i
        case .info: return 100000
        }
    }
    
    static func == (lhs: KeywordListEntry, rhs: KeywordListEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.input(a), .input(b)): return a == b
        case let (.word(i, a), .word(j, b)): return i == j && a == b
        case let (.info(a), .info(b)): return a == b
        default: return false
        }
    }
    
    static func < (lhs: KeywordListEntry, rhs: KeywordListEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KeywordListArguments
        switch self {
        case let .input(placeholder):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                title: NSAttributedString(string: ""),
                text: "",
                placeholder: placeholder,
                type: .default,
                returnKeyType: .done,
                clearType: .always,
                maxLength: 64,
                sectionId: section,
                textUpdated: { _ in },
                updatedFocus: { _ in },
                tag: nil
            )
        case let .word(_, text):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "删除", sectionId: section, style: .blocks, action: {
                arguments.removeWord(text)
            })
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        }
    }
}

public func contentFilterKeywordListController(context: AccountContext, isBlacklist: Bool) -> ViewController {
    let currentInput = Atomic<String>(value: "")
    
    let arguments = KeywordListArguments(
        addWord: { text in
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            let _ = updateContentFilterSettingsInteractively(accountManager: context.sharedContext.accountManager) { current in
                if isBlacklist {
                    var list = current.blacklist
                    if !list.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                        list.append(t)
                    }
                    return current.withUpdatedBlacklist(list)
                } else {
                    var list = current.whitelist
                    if !list.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                        list.append(t)
                    }
                    return current.withUpdatedWhitelist(list)
                }
            }.start()
            let _ = currentInput.swap("")
        },
        removeWord: { word in
            let _ = updateContentFilterSettingsInteractively(accountManager: context.sharedContext.accountManager) { current in
                if isBlacklist {
                    return current.withUpdatedBlacklist(current.blacklist.filter { $0 != word })
                } else {
                    return current.withUpdatedWhitelist(current.whitelist.filter { $0 != word })
                }
            }.start()
        }
    )
    
    // Custom item builder with live input that commits on return
    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.contentFilterSettings])
    
    enum LiveKeywordEntry: ItemListNodeEntry {
        case inputField(String)
        case addButton(String)
        case word(Int32, String)
        case info(String)
        
        var section: ItemListSectionId {
            switch self {
            case .inputField, .addButton: return 0
            default: return 1
            }
        }
        var stableId: Int32 {
            switch self {
            case .inputField: return -2
            case .addButton: return -1
            case let .word(i, _): return i
            case .info: return 99999
            }
        }
        static func == (l: LiveKeywordEntry, r: LiveKeywordEntry) -> Bool {
            switch (l, r) {
            case let (.inputField(a), .inputField(b)): return a == b
            case let (.addButton(a), .addButton(b)): return a == b
            case let (.word(i, a), .word(j, b)): return i == j && a == b
            case let (.info(a), .info(b)): return a == b
            default: return false
            }
        }
        static func < (l: LiveKeywordEntry, r: LiveKeywordEntry) -> Bool { l.stableId < r.stableId }
        
        func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
            let args = arguments as! KeywordListArguments
            switch self {
            case let .inputField(placeholder):
                return ItemListSingleLineInputItem(
                    presentationData: presentationData,
                    title: NSAttributedString(string: "关键词"),
                    text: "",
                    placeholder: placeholder,
                    type: .default,
                    returnKeyType: .done,
                    clearType: .always,
                    maxLength: 64,
                    sectionId: section,
                    textUpdated: { text in
                        let _ = currentInput.swap(text)
                    },
                    updatedFocus: { _ in },
                    tag: nil
                )
            case let .addButton(title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: section, style: .blocks, action: {
                    args.addWord(currentInput.with { $0 })
                })
            case let .word(_, text):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "删除", sectionId: section, style: .blocks, action: {
                    args.removeWord(text)
                })
            case let .info(text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
            }
        }
    }
    
    let signal = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, sharedData)
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.contentFilterSettings]?.get(ContentFilterSettings.self)
            ?? ContentFilterSettings.defaultSettings
        let words = isBlacklist ? settings.blacklist : settings.whitelist
        
        var entries: [LiveKeywordEntry] = []
        entries.append(.inputField(isBlacklist ? "输入要屏蔽的词" : "输入白名单词"))
        entries.append(.addButton("添加"))
        for (i, w) in words.enumerated() {
            entries.append(.word(Int32(i), w))
        }
        entries.append(.info(isBlacklist
            ? "包含这些词的消息将从信息流中隐藏。"
            : "包含这些词的消息即使命中黑名单也会显示。"))
        
        let title = isBlacklist ? "黑名单" : "白名单"
        let state = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(title),
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
        return (state, (listState, arguments as Any))
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.alwaysSynchronous = true
    return controller
}
