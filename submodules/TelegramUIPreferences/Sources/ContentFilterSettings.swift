import Foundation
import TelegramCore
import SwiftSignalKit

public struct ContentFilterSettings: Codable, Equatable {
    /// 自动隐藏信息流中的广告
    public var hideAds: Bool
    /// 黑名单关键词（命中则隐藏消息）
    public var blacklist: [String]
    /// 白名单关键词（命中则强制显示，优先于黑名单）
    public var whitelist: [String]
    /// 是否启用关键词过滤
    public var filterEnabled: Bool
    
    public static var defaultSettings: ContentFilterSettings {
        return ContentFilterSettings(
            hideAds: true,
            blacklist: [],
            whitelist: [],
            filterEnabled: true
        )
    }
    
    public init(hideAds: Bool, blacklist: [String], whitelist: [String], filterEnabled: Bool) {
        self.hideAds = hideAds
        self.blacklist = blacklist
        self.whitelist = whitelist
        self.filterEnabled = filterEnabled
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: StringCodingKey.self)
        self.hideAds = try c.decodeIfPresent(Bool.self, forKey: "hideAds") ?? true
        self.blacklist = try c.decodeIfPresent([String].self, forKey: "blacklist") ?? []
        self.whitelist = try c.decodeIfPresent([String].self, forKey: "whitelist") ?? []
        self.filterEnabled = try c.decodeIfPresent(Bool.self, forKey: "filterEnabled") ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: StringCodingKey.self)
        try c.encode(hideAds, forKey: "hideAds")
        try c.encode(blacklist, forKey: "blacklist")
        try c.encode(whitelist, forKey: "whitelist")
        try c.encode(filterEnabled, forKey: "filterEnabled")
    }
    
    /// 判断文本是否应被隐藏
    public func shouldHide(text: String) -> Bool {
        guard filterEnabled else { return false }
        let lower = text.lowercased()
        // 白名单优先：命中白名单则不隐藏
        for w in whitelist {
            let t = w.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            if lower.contains(t.lowercased()) { return false }
        }
        for b in blacklist {
            let t = b.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            if lower.contains(t.lowercased()) { return true }
        }
        return false
    }
    
    public func withUpdatedHideAds(_ v: Bool) -> ContentFilterSettings {
        var s = self; s.hideAds = v; return s
    }
    public func withUpdatedFilterEnabled(_ v: Bool) -> ContentFilterSettings {
        var s = self; s.filterEnabled = v; return s
    }
    public func withUpdatedBlacklist(_ v: [String]) -> ContentFilterSettings {
        var s = self; s.blacklist = v; return s
    }
    public func withUpdatedWhitelist(_ v: [String]) -> ContentFilterSettings {
        var s = self; s.whitelist = v; return s
    }
}

public func updateContentFilterSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (ContentFilterSettings) -> ContentFilterSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.contentFilterSettings, { entry in
            let current: ContentFilterSettings
            if let entry = entry?.get(ContentFilterSettings.self) {
                current = entry
            } else {
                current = ContentFilterSettings.defaultSettings
            }
            return SharedPreferencesEntry(f(current))
        })
    }
}
