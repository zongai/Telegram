import Foundation

/// 全局多线程下载配置（可由设置页写入）
public enum MultipartDownloadConfig {
    /// 是否启用多线程分片下载
    public static var multiThreadEnabled: Bool = true
    /// 大文件并行分片数上限（官方默认约 8）
    public static var maxParallelParts: Int = 16
    /// 小文件并行分片数
    public static var smallFileParallelParts: Int = 16
    /// 默认分片大小（大文件）
    public static var largePartSize: Int64 = 512 * 1024
    /// 小文件分片大小
    public static var smallPartSize: Int64 = 32 * 1024
    
    public static func apply(multiThreadEnabled: Bool, maxParallelParts: Int) {
        self.multiThreadEnabled = multiThreadEnabled
        self.maxParallelParts = max(1, min(32, maxParallelParts))
        self.smallFileParallelParts = max(4, min(32, maxParallelParts))
    }
}
