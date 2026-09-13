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

/// 路由资源：每一条通过 `Route.privilege(...)` 登记的受保护路由对应一个 RouterResource。
///
/// `appId` 形如 `"GET /api/no_protect"`（多次登记同一路由时依次追加 `#1`、`#2`…），
/// 仲裁时以 `input.resource.appId` 出现在 OPA input 中，可在权限主系统的角色 / 域策略中引用，例如：
///
///     allow if { startswith(input.resource.appId, "GET /api/report") }
@Resource
struct RouterResource {
    typealias ResourceType = ResourceList
    static let type: ResourceList = .router
    
    /// 资源标识，见类型说明
    var appId: String
    
    enum Operations: String, OperationList {
        /// 访问（执行）该路由
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
                RouterResource(appId: stableAppId()),
                op: .run,
                using: privileges
            )
        )
    }
    
    /// 生成**稳定**的资源标识：`"<METHOD> <path>"`，同一路由多次登记时追加 `#<序号>`。
    private func stableAppId() -> String {
        // Vapor 的 `[PathComponent].string` 只是用 "/" 拼接各段（"api/no_protect"），不带前导斜杠，这里补上以符合 "GET /api/no_protect" 的约定
        let base = "\(self.method) /\(self.path.string)"
        // 同一 Route 上此前已登记的资源数量（Route.privilege(bundle:) 会把多次登记追加到 userInfo 中）
        // 注意："resource_key" 是 PrivilegeModuleDriver 中 `Route.resourceKey` 的字面值（该常量为 internal，无法直接引用）
        let existing = (self.userInfo["resource_key"] as? OrderedSet<AnyResource>)?.count ?? 0
        return existing == 0 ? base : "\(base)#\(existing)"
    }
}
