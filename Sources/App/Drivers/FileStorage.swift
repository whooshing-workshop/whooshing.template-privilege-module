import FileStorageDriver

/// 在此处配置文件加密存储模块，仅允许配置一个，默认为全局单例模式
/// 文件加密存储模块需要将文件索引存入一个数据库中，因此它需要绑定一个数据库实例
/// 使用 `Woo.inline.syncMakeFileStorage` 初始化一个 FileStorage 对象，可在全局使用
/// 一旦初始化失败将会导致服务崩溃
extension FileStorage {
    
    /// 默认文件存储模块，其加密文件的存储位置在 "default" 文件夹下(沙盒中)
    /// 使用数据库服务 "default" 中的 "file_storage" 数据库存储文件索引
    /// 创建了一个最基本的 Logger，仅将日志记录打印在程序输出中
    /// 自动创建根文件夹(加密文件的存储文件夹，相对于沙盒的路径)如果其不存在
    /// 若在独立测试环境中，则启动 debugging 模式，否则使用正常的生产或开发模式
    static let `default`: FileStorage = {
        Woo.nexus.syncMakeFileStorage(
            for: db(name: "file_storage", from: "default"),
            storagePath: "default",
            logger: Woo.logger,
            dirCreateAction: .createIfNeed(withIntermediateDirectories: true),
            debugging: Woo.isIndependentDebug
        )
    }()
}

extension Request {
    var fileStorage: FileStorage { FileStorage.default }
}
