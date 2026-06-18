import Vapor
import Logging
import PrivilegeModule
import PrivilegeModuleDriver
import WhooshingServer
import ResourceMacros
import AnyCodable

enum ResourceList: String, ResourceTypeList {
    case file
}

@Resource
struct FileResource {
    typealias ResourceType = ResourceList
    static let type: ResourceList = .file
    
    let name: String
    
    enum Operations: String, OperationList {
        case read
        case write
        case execute
    }
}

/// 在此处配置权限模块，仅允许配置一个，默认为全局单例模式
/// 权限模块需要保存权限结构至数据库中，因此需要绑定一个数据库实例
/// 使用 `Woo.inline.syncMakeModuleSystem` 初始化一个 PrivilegeModule 对象，可在全局使用
/// 一旦初始化失败将会导致服务崩溃
extension PrivilegeModule<ResourceList> {
    
    /// 权限模块，使用数据库服务 "default" 中的 "privilege_module" 数据库存储权限结构
    /// 创建了一个最基本的 Logger，仅将日志记录打印在程序输出中
    /// 若在独立测试环境中，则启动 debugging 模式，否则使用正常的生产或开发模式
    static let module: PrivilegeModule<ResourceList> = {
        Woo.inline.syncMakePrivilegeModule(
            for: db(name: "privilege_module", from: "default", in: Woo.inline),
            logger: Woo.logger,
            debugging: Woo.isIndependentDebug
        )
    }()
}
