import Foundation
import TelegramCore
import SwiftSignalKit

public struct DownloadCacheSettings: Codable, Equatable {
    /// 多线程下载
    public var multiThreadDownload: Bool
    /// 并行分片数 4…32
    public var parallelParts: Int
    /// 自动清理缓存
    public var autoCleanupEnabled: Bool
    /// 缓存保留天数（超过则清理）
    public var keepDays: Int
    /// 缓存上限（MB，0 = 不限）
    public var maxCacheMB: Int
    /// 上次自动清理时间（unix）
    public var lastCleanupTimestamp: Int32
    
    public static var defaultSettings: DownloadCacheSettings {
        return DownloadCacheSettings(
            multiThreadDownload: true,
            parallelParts: 16,
            autoCleanupEnabled: true,
            keepDays: 7,
            maxCacheMB: 2048,
            lastCleanupTimestamp: 0
        )
    }
    
    public init(multiThreadDownload: Bool, parallelParts: Int, autoCleanupEnabled: Bool, keepDays: Int, maxCacheMB: Int, lastCleanupTimestamp: Int32) {
        self.multiThreadDownload = multiThreadDownload
        self.parallelParts = parallelParts
        self.autoCleanupEnabled = autoCleanupEnabled
        self.keepDays = keepDays
        self.maxCacheMB = maxCacheMB
        self.lastCleanupTimestamp = lastCleanupTimestamp
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: StringCodingKey.self)
        self.multiThreadDownload = try c.decodeIfPresent(Bool.self, forKey: "mtd") ?? true
        self.parallelParts = try c.decodeIfPresent(Int.self, forKey: "pp") ?? 16
        self.autoCleanupEnabled = try c.decodeIfPresent(Bool.self, forKey: "ace") ?? true
        self.keepDays = try c.decodeIfPresent(Int.self, forKey: "kd") ?? 7
        self.maxCacheMB = try c.decodeIfPresent(Int.self, forKey: "mcm") ?? 2048
        self.lastCleanupTimestamp = try c.decodeIfPresent(Int32.self, forKey: "lct") ?? 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: StringCodingKey.self)
        try c.encode(multiThreadDownload, forKey: "mtd")
        try c.encode(parallelParts, forKey: "pp")
        try c.encode(autoCleanupEnabled, forKey: "ace")
        try c.encode(keepDays, forKey: "kd")
        try c.encode(maxCacheMB, forKey: "mcm")
        try c.encode(lastCleanupTimestamp, forKey: "lct")
    }
    
    public func applyToMultipartConfig() {
        MultipartDownloadConfig.apply(
            multiThreadEnabled: multiThreadDownload,
            maxParallelParts: parallelParts
        )
    }
    
    public func withUpdatedMultiThreadDownload(_ v: Bool) -> DownloadCacheSettings {
        var s = self; s.multiThreadDownload = v; return s
    }
    public func withUpdatedParallelParts(_ v: Int) -> DownloadCacheSettings {
        var s = self; s.parallelParts = max(4, min(32, v)); return s
    }
    public func withUpdatedAutoCleanupEnabled(_ v: Bool) -> DownloadCacheSettings {
        var s = self; s.autoCleanupEnabled = v; return s
    }
    public func withUpdatedKeepDays(_ v: Int) -> DownloadCacheSettings {
        var s = self; s.keepDays = max(1, min(365, v)); return s
    }
    public func withUpdatedMaxCacheMB(_ v: Int) -> DownloadCacheSettings {
        var s = self; s.maxCacheMB = max(0, v); return s
    }
    public func withUpdatedLastCleanupTimestamp(_ v: Int32) -> DownloadCacheSettings {
        var s = self; s.lastCleanupTimestamp = v; return s
    }
}

public func updateDownloadCacheSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (DownloadCacheSettings) -> DownloadCacheSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.downloadCacheSettings, { entry in
            let current: DownloadCacheSettings
            if let entry = entry?.get(DownloadCacheSettings.self) {
                current = entry
            } else {
                current = DownloadCacheSettings.defaultSettings
            }
            let updated = f(current)
            updated.applyToMultipartConfig()
            return SharedPreferencesEntry(updated)
        })
    }
}
