import Foundation
import TelegramPresentationData

/// 下载速度采样与格式化：根据进度字节数估算瞬时速度
public final class DownloadSpeedTracker {
    public static let shared = DownloadSpeedTracker()
    
    private struct Sample {
        let time: CFTimeInterval
        let bytes: Int64
    }
    
    private var samples: [String: [Sample]] = [:]
    private let lock = NSLock()
    private let windowSeconds: CFTimeInterval = 2.0
    private let maxSamples = 12
    
    private init() {}
    
    /// 更新已下载字节，返回估算速度（字节/秒）；样本不足时返回 nil
    public func update(key: String, downloadedBytes: Int64) -> Int64? {
        let now = CFAbsoluteTimeGetCurrent()
        lock.lock()
        defer { lock.unlock() }
        
        var list = samples[key] ?? []
        // 避免相同字节重复采样
        if let last = list.last, last.bytes == downloadedBytes, now - last.time < 0.15 {
            return computeSpeed(samples: list)
        }
        list.append(Sample(time: now, bytes: downloadedBytes))
        if list.count > maxSamples {
            list.removeFirst(list.count - maxSamples)
        }
        // 丢弃窗口外样本
        list = list.filter { now - $0.time <= windowSeconds * 2 }
        samples[key] = list
        return computeSpeed(samples: list)
    }
    
    public func clear(key: String) {
        lock.lock()
        samples.removeValue(forKey: key)
        lock.unlock()
    }
    
    private func computeSpeed(samples: [Sample]) -> Int64? {
        guard samples.count >= 2 else { return nil }
        let first = samples.first!
        let last = samples.last!
        let dt = last.time - first.time
        guard dt >= 0.25 else { return nil }
        let db = last.bytes - first.bytes
        guard db >= 0 else { return nil }
        return Int64(Double(db) / dt)
    }
}

/// 格式化为 "2.3 MB/s" / "850 KB/s"
public func downloadSpeedString(_ bytesPerSecond: Int64, formatting: DataSizeStringFormatting) -> String {
    if bytesPerSecond <= 0 {
        return ""
    }
    let sizePart = dataSizeString(bytesPerSecond, forceDecimal: true, formatting: formatting)
    return "\(sizePart)/s"
}

/// 在进度文案后附加速度： "1.2 MB / 5.0 MB · 2.5 MB/s"
public func progressStringWithSpeed(
    key: String,
    downloaded: Int64,
    total: Int64,
    formatting: DataSizeStringFormatting,
    separator: String = " · "
) -> String {
    let base = "\(dataSizeString(downloaded, forceDecimal: true, formatting: formatting)) / \(dataSizeString(total, forceDecimal: true, formatting: formatting))"
    if let bps = DownloadSpeedTracker.shared.update(key: key, downloadedBytes: downloaded), bps > 0 {
        let speed = downloadSpeedString(bps, formatting: formatting)
        if !speed.isEmpty {
            return base + separator + speed
        }
    }
    return base
}

public func progressStringWithSpeed(
    key: String,
    progress: Float,
    total: Int64,
    formatting: DataSizeStringFormatting,
    separator: String = " · "
) -> String {
    let downloaded = Int64(Float(total) * max(0, min(1, progress)))
    return progressStringWithSpeed(key: key, downloaded: downloaded, total: total, formatting: formatting, separator: separator)
}
