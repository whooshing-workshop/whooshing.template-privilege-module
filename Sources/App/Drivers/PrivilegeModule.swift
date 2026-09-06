import PrivilegeModuleDriver

// MARK: - 资源列表定义

/// 资源类型清单
///
/// 该枚举定义了本系统所有的资源类型，每种类型应当对应一个 Resource 类型
/// 作为例子，可见 `FileResource` 类型，其 type 类属性被设置为 .file
enum ResourceList: String, ResourceTypeList {
    case file
    case router
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
    let appId: String
    
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

@Resource
struct RouterResource {
    typealias ResourceType = ResourceList
    static let type: ResourceList = .router
    
    var appId: String
    
    enum Operations: String, OperationList {
        case run
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
        Woo.nexus.syncMakePrivilegeModule(
            for: db(name: "privilege_module", from: "default"),
            logger: Woo.logger,
            debugging: Woo.isIndependentDebug
        )
    }()
}

extension Request {
    var privilegeModule: PrivilegeModule<ResourceList> { PrivilegeModule.module }
}

extension Route {
    @discardableResult
    func privilege(
        name: String? = nil,
        summary: String? = nil,
        by policy: PrivilegePolicy
    ) -> Self {
        self.privilege(
            using: [.init(name: name, summary: summary, policy: policy.policy)]
        )
    }
    
    @discardableResult
    func privilege(
        name: String? = nil,
        summary: String? = nil,
        by policy: @Sendable @escaping (PrivilegePolicy) -> PrivilegePolicy
    ) -> Self {
        self.privilege(
            using: [.init(name: name, summary: summary, policy: policy(.init()).policy)]
        )
    }
    
    @discardableResult
    func privilege(
        using privilege: PrivilegeModule<ResourceList>.PPrivilege
    ) -> Self {
        self.privilege(
            using: [privilege]
        )
    }
    
    @discardableResult
    func privilege(
        using policies: OrderedSet<PrivilegePolicy>
    ) -> Self {
        self.privilege(
            using: policies.mapToSet { .init(policy: $0.policy) }
        )
    }
    
    @discardableResult
    func privilege(
        using privileges: OrderedSet<PrivilegeModule<ResourceList>.PPrivilege>
    ) -> Self {
        self.privilege(
            bundle: .init(
                RouterResource(appId: self.path.string + "/" + stamp()),
                op: .run,
                using: privileges
            )
        )
    }
    
    private func stamp() -> String {
        // 获取毫秒级时间戳（13 位数字）
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        // 生成 0 ~ 99999 的随机数，并用 0 补齐 5 位
        let randomPart = Int.random(in: 0...99999)
        let randomString = String(format: "%05d", randomPart)
        
        // 拼接输出（共 18 位纯数字）
        return "\(timestamp)/\(randomString)"
    }
}
