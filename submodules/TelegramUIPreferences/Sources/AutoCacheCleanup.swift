import Foundation
import TelegramCore
import SwiftSignalKit
import Postbox

/// 自动清理缓存调度（由 UI 层在启动/回前台时调用 `maybeRun`）
public enum AutoCacheCleanup {
    private static let minIntervalSeconds: Int32 = 6 * 3600
    
    /// 应用多线程下载配置，并在需要时执行清理
    public static func maybeRun(
        accountManager: AccountManager<TelegramAccountManagerTypes>,
        postbox: Postbox,
        tempPaths: [String] = [],
        collectAndClear: @escaping (DownloadCacheSettings) -> Signal<Void, NoError>
    ) {
        let _ = (accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.downloadCacheSettings])
        |> take(1)
        |> mapToSignal { sharedData -> Signal<Void, NoError> in
            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.downloadCacheSettings]?.get(DownloadCacheSettings.self)
                ?? DownloadCacheSettings.defaultSettings
            settings.applyToMultipartConfig()
            
            guard settings.autoCleanupEnabled else {
                return .complete()
            }
            let now = Int32(Date().timeIntervalSince1970)
            if settings.lastCleanupTimestamp > 0 && now - settings.lastCleanupTimestamp < minIntervalSeconds {
                return .complete()
            }
            
            return collectAndClear(settings)
            |> then(Signal { subscriber in
                // 轻量 postbox 缓存
                postbox.clearCaches()
                // 过期临时文件
                let cutoff = Date().addingTimeInterval(-TimeInterval(settings.keepDays * 24 * 3600))
                for path in tempPaths {
                    removeOldFiles(at: path, olderThan: cutoff)
                }
                subscriber.putCompletion()
                return EmptyDisposable
            })
            |> mapToSignal { _ in
                updateDownloadCacheSettingsInteractively(accountManager: accountManager) {
                    $0.withUpdatedLastCleanupTimestamp(now)
                }
            }
        }).start()
    }
    
    /// 仅应用多线程下载配置（不清理）
    public static func applyDownloadConfig(accountManager: AccountManager<TelegramAccountManagerTypes>) {
        let _ = (accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.downloadCacheSettings])
        |> take(1)
        |> map { sharedData in
            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.downloadCacheSettings]?.get(DownloadCacheSettings.self)
                ?? DownloadCacheSettings.defaultSettings
            settings.applyToMultipartConfig()
        }).start()
    }
    
    public static func removeOldFiles(at path: String, olderThan cutoff: Date) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path), let en = fm.enumerator(atPath: path) else { return }
        for case let name as String in en {
            let full = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue { continue }
            if let attrs = try? fm.attributesOfItem(atPath: full),
               let mod = attrs[.modificationDate] as? Date,
               mod < cutoff {
                try? fm.removeItem(atPath: full)
            }
        }
    }
}
