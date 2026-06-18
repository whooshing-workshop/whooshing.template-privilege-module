import Vapor
import Logging
import PrivilegeModule
import PrivilegeModuleDriver
import WhooshingServer
import ResourceMacros
import AnyCodable

// MARK: - 资源列表定义

/// 资源类型清单
///
/// 该枚举定义了本系统所有的资源类型，每种类型应当对应一个 Resource 类型
/// 作为例子，可见 `FileResource` 类型，其 type 类属性被设置为 .file
enum ResourceList: String, ResourceTypeList {
    case file
}

// MARK: - 资源定义

/// 资源类型可以有多个，根据您的需求创建，但**每种类型必须对应一个 Resource 类型**
/// 以下作为例子，创建了一个 FileResource 资源

/// 文件资源结构体
///
/// 该结构体使用 @Resource 定义了一个资源
/// 每个资源必须绑定一个资源类型 (ResourceList) 以及操作清单 (Operations)
@Resource
struct FileResource {
    typealias ResourceType = ResourceList
    static let type: ResourceList = .file
    
    /// 该(文件)资源的名称
    let name: String
    
    /// 该文件的路径
    let path: String
    
    /// 该资源的操作清单
    /// 列举了该资源所有可能的操作，可用于权限判断
    enum Operations: String, OperationList {
        /// 文件读取权限
        case read
        /// 文件写入权限
        case write
    }
}

// MARK: - 权限模块定义

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
