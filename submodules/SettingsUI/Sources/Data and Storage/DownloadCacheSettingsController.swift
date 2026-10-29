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

private final class DownloadCacheArguments {
    let toggleMultiThread: (Bool) -> Void
    let setParallelParts: (Int) -> Void
    let toggleAutoCleanup: (Bool) -> Void
    let setKeepDays: (Int) -> Void
    let setMaxCacheMB: (Int) -> Void
    let runCleanupNow: () -> Void
    
    init(toggleMultiThread: @escaping (Bool) -> Void, setParallelParts: @escaping (Int) -> Void, toggleAutoCleanup: @escaping (Bool) -> Void, setKeepDays: @escaping (Int) -> Void, setMaxCacheMB: @escaping (Int) -> Void, runCleanupNow: @escaping () -> Void) {
        self.toggleMultiThread = toggleMultiThread
        self.setParallelParts = setParallelParts
        self.toggleAutoCleanup = toggleAutoCleanup
        self.setKeepDays = setKeepDays
        self.setMaxCacheMB = setMaxCacheMB
        self.runCleanupNow = runCleanupNow
    }
}

private enum DCSection: Int32 { case download = 0; case cache = 1; case actions = 2 }

private enum DCEntry: ItemListNodeEntry {
    case multiThread(String, Bool)
    case parallel(String, String)
    case downloadInfo(String)
    case autoCleanup(String, Bool)
    case keepDays(String, String)
    case maxCache(String, String)
    case cacheInfo(String)
    case cleanupNow(String)
    
    var section: ItemListSectionId {
        switch self {
        case .multiThread, .parallel, .downloadInfo: return DCSection.download.rawValue
        case .autoCleanup, .keepDays, .maxCache, .cacheInfo: return DCSection.cache.rawValue
        case .cleanupNow: return DCSection.actions.rawValue
        }
    }
    var stableId: Int32 {
        switch self {
        case .multiThread: return 0
        case .parallel: return 1
        case .downloadInfo: return 2
        case .autoCleanup: return 10
        case .keepDays: return 11
        case .maxCache: return 12
        case .cacheInfo: return 13
        case .cleanupNow: return 20
        }
    }
    static func == (l: DCEntry, r: DCEntry) -> Bool {
        switch (l, r) {
        case let (.multiThread(a,b), .multiThread(c,d)): return a==c && b==d
        case let (.parallel(a,b), .parallel(c,d)): return a==c && b==d
        case let (.downloadInfo(a), .downloadInfo(b)): return a==b
        case let (.autoCleanup(a,b), .autoCleanup(c,d)): return a==c && b==d
        case let (.keepDays(a,b), .keepDays(c,d)): return a==c && b==d
        case let (.maxCache(a,b), .maxCache(c,d)): return a==c && b==d
        case let (.cacheInfo(a), .cacheInfo(b)): return a==b
        case let (.cleanupNow(a), .cleanupNow(b)): return a==b
        default: return false
        }
    }
    static func < (l: DCEntry, r: DCEntry) -> Bool { l.stableId < r.stableId }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! DownloadCacheArguments
        switch self {
        case let .multiThread(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: section, style: .blocks, updated: { args.toggleMultiThread($0) })
        case let .parallel(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: section, style: .blocks, action: {
                // cycle 8 → 12 → 16 → 24 → 32 → 8
                let map = [8, 12, 16, 24, 32]
                let current = Int(value.replacingOccurrences(of: " 线程", with: "")) ?? 16
                let next = map.first(where: { $0 > current }) ?? map[0]
                args.setParallelParts(next)
            })
        case let .downloadInfo(text), let .cacheInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: section)
        case let .autoCleanup(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: section, style: .blocks, updated: { args.toggleAutoCleanup($0) })
        case let .keepDays(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: section, style: .blocks, action: {
                let options = [3, 7, 14, 30, 90]
                let current = Int(value.replacingOccurrences(of: " 天", with: "")) ?? 7
                let next = options.first(where: { $0 > current }) ?? options[0]
                args.setKeepDays(next)
            })
        case let .maxCache(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: section, style: .blocks, action: {
                let options = [512, 1024, 2048, 4096, 0]
                let current: Int
                if value.contains("不限") { current = 0 }
                else { current = Int(value.replacingOccurrences(of: " MB", with: "")) ?? 2048 }
                let idx = options.firstIndex(of: current) ?? 0
                let next = options[(idx + 1) % options.count]
                args.setMaxCacheMB(next)
            })
        case let .cleanupNow(title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: section, style: .blocks, action: {
                args.runCleanupNow()
            })
        }
    }
}

private func entries(settings: DownloadCacheSettings) -> [DCEntry] {
    var e: [DCEntry] = []
    e.append(.multiThread("多线程下载", settings.multiThreadDownload))
    e.append(.parallel("并行分片数", "\(settings.parallelParts) 线程"))
    e.append(.downloadInfo("大文件将按分片并行拉取，提高下载速度。可设 4–32。"))
    e.append(.autoCleanup("自动清理缓存", settings.autoCleanupEnabled))
    e.append(.keepDays("缓存保留时间", "\(settings.keepDays) 天"))
    let maxLabel = settings.maxCacheMB == 0 ? "不限制" : "\(settings.maxCacheMB) MB"
    e.append(.maxCache("缓存上限", maxLabel))
    e.append(.cacheInfo("超过保留时间或体积上限时自动清理媒体缓存。最多每 6 小时执行一次。"))
    e.append(.cleanupNow("立即清理缓存"))
    return e
}

public func downloadCacheSettingsController(context: AccountContext) -> ViewController {
    let arguments = DownloadCacheArguments(
        toggleMultiThread: { v in
            let _ = updateDownloadCacheSettingsInteractively(accountManager: context.sharedContext.accountManager) {
                $0.withUpdatedMultiThreadDownload(v)
            }.start()
        },
        setParallelParts: { v in
            let _ = updateDownloadCacheSettingsInteractively(accountManager: context.sharedContext.accountManager) {
                $0.withUpdatedParallelParts(v)
            }.start()
        },
        toggleAutoCleanup: { v in
            let _ = updateDownloadCacheSettingsInteractively(accountManager: context.sharedContext.accountManager) {
                $0.withUpdatedAutoCleanupEnabled(v)
            }.start()
        },
        setKeepDays: { v in
            let _ = updateDownloadCacheSettingsInteractively(accountManager: context.sharedContext.accountManager) {
                $0.withUpdatedKeepDays(v)
            }.start()
        },
        setMaxCacheMB: { v in
            let _ = updateDownloadCacheSettingsInteractively(accountManager: context.sharedContext.accountManager) {
                $0.withUpdatedMaxCacheMB(v)
            }.start()
        },
        runCleanupNow: {
            let settings = DownloadCacheSettings.defaultSettings
            let _ = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.downloadCacheSettings])
            |> take(1)
            |> mapToSignal { sharedData -> Signal<Void, NoError> in
                let s = sharedData.entries[ApplicationSpecificSharedDataKeys.downloadCacheSettings]?.get(DownloadCacheSettings.self) ?? settings
                return context.engine.resources.collectCacheUsageStats(additionalCachePaths: [], logFilesPath: nil)
                |> take(1)
                |> mapToSignal { result -> Signal<Void, NoError> in
                    var ids = Set<MediaResourceId>()
                    if case let .result(stats) = result {
                        for (_, resources) in stats.mediaResourceIds {
                            for id in resources { ids.insert(id) }
                        }
                        let cutoff = Date().addingTimeInterval(-TimeInterval(s.keepDays * 24 * 3600))
                        for path in stats.tempPaths + stats.otherPaths {
                            AutoCacheCleanup.removeOldFiles(at: path, olderThan: cutoff)
                        }
                    }
                    if ids.isEmpty {
                        return Signal { sub in
                            context.account.postbox.clearCaches()
                            sub.putCompletion()
                            return EmptyDisposable
                        }
                    }
                    return context.engine.resources.clearCachedMediaResources(
                        mediaResourceIds: Set(ids.map { EngineMediaResource.Id($0.stringRepresentation) })
                    ) |> map { _ in } |> then(Signal { sub in
                        context.account.postbox.clearCaches()
                        sub.putCompletion()
                        return EmptyDisposable
                    })
                }
            }).start()
        }
    )
    
    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.downloadCacheSettings])
    let signal = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, sharedData)
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.downloadCacheSettings]?.get(DownloadCacheSettings.self)
            ?? DownloadCacheSettings.defaultSettings
        settings.applyToMultipartConfig()
        let state = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("下载与缓存"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries(settings: settings),
            style: .blocks,
            animateChanges: true
        )
        return (state, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.alwaysSynchronous = true
    return controller
}
