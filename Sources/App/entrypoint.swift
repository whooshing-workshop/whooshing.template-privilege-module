import VaporTube
import FileStorageDriver
import PrivilegeModuleDriver

/// 该函数为入口函数，是整个 Whooshing 服务的执行起始点
/// 该函数根据环境变量(API, HTTPS)分别设置服务类型，并进行初始化
/// 环境变量可在 Package.swift 中设置
/// 不同服务的 Application 实例可以分别通过 Woo.api, Woo.inline, Woo.https 来取得
/// 要对不同的实例进行额外配置，在 configure.swift 进行额外配置
///
/// 服务运行时，会根据启动参数决定所运行的模式
/// 根据不同的启动参数有：
///
/// swift run App serve --env production
/// swift run App serve --env development
/// swift run App serve --env testing
///
/// 分别对应 生产，开发，测试 环境
/// 若是 xcode 构建，则默认为 development 环境
@main
enum Woo {
    /// 该服务模块的名称
    static let appName = "App"
    
    /// 配置该服务模块是否接受运行在测试环境中，可将其改为 false
    /// 这样，若检测到环境为 testing 将会直接 fatalError
    /// 另请详见 `Mode`
    static let testingAllowed = true
    
    /// 指示当前环境是否为独立调试模式
    static let isIndependentDebug: Bool = mode.envrionment != .production && testingAllowed
    
    /// 所加载的驱动，该模块加载
    ///     FileStorage: 文件加密存储模块
    ///     PrivilegeModule: 权限模块
    static let driverKeys: [any Environment.DriverKey.Type] = [FileStorageDriverKey.self, PrivilegeModuleDriverKey.self]
    
    /// 该模块的日志配置
    static let logger: Logger = {
        var logger = Logger(label: appName.lowercased())
        /// 指定所有日志的记录等级
        logger.logLevel = .info
        return logger
    }()
}

/// 从 `dbServices` 中根据名称取得数据库的配置
///
/// - Parameters:
///     - name: 数据库的名称
///     - service: 数据库服务的名称
/// - Returns: 所创建的数据库服务
///
/// 如果未找到，将直接导致程序崩溃
func db(name: String, from service: String) -> Environment.DB {
    guard let dbService = (Woo.nexus.config.dbServices.first { $0.id.string == service }) else {
        fatalError("未找到所指定的数据库服务配置")
    }
    guard let db = (dbService.dbs.first { $0.id == .init(string: "\(service)/\(name)") }) else {
        fatalError("未能找到所指定的数据库配置")
    }
    return db
}

/// 用于调试模式的参数，仅在独立调试和测试模式下生效，不会在生产或非独立开发模式下生效
/// 关于模式，见 `Whooshing.Mode`
struct DebuggingParameters {
    /// 客户端访问 api 服务时所必须持有的凭据，若凭据不正确，则会拒绝该用户的连线
    static let clientCredential = "bRRPIiYbt0t4RzfqeeHSkg=="
    
    /// 客户端访问 api 服务时所必须持有的口令，若口令不正确，则会拒绝该用户的连线
    static let clientToken = SendableSymmKey(key: .init(data: Data(base64Encoded: clientTokenStr)!))
    static let clientTokenStr = "jXTz4vTQk0O/XFIjWQIHLC7z9/E0/4VtEb+LkF8IcA4="
    
    /// 服务监听的段口号
    static let port = 6500
    
    /// 初始化文件加密存储模块的配置，此处设置，将连接到所有的服务模块
    /// FileStorage 为全局单例模式，一个服务模块仅能部署一个文件存储实例
    /// 这些参数仅在独立测试环境中可用
    /// 生产环境中将由 Whooshing 系统提供所有的配置参数
    ///
    /// dir 参数指定该文件系统的加密文件所存储的真实磁盘位置
    /// 若该 URL 路径不存在，系统会自动创建包括所有的路径中间目录
    /// 作为默认配置，FileStorage 的加密文件将保存在 ~/app_file_storage 文件夹中
    static let fileStorageParas = Environment.FS(
        dir: URL.homeDirectoryURL.appending(component: "app_file_storage")
    )
    
    /// 初始化权限模块的配置，此处设置，将连接到所有的服务模块
    /// PrivilegeModule 为全局单例模式，一个服务模块仅能部署一个权限模块实例
    /// 这些参数仅在独立测试环境中可用
    /// 生产环境中将由 Whooshing 系统提供所有的配置参数
    ///
    /// 权限主系统依赖 EOPA 进行权限仲裁操作，确保该服务已经部署，并提供:
    ///     - scheme: 连线协议 http 或 https
    ///     - host: EOPA 所在的 ip 地址或域名
    ///     - port: EOPA 监听的端口号
    static let privilegeModuleParas = Environment.PM(
        eopa: .init(
            scheme: .http,
            port: 8181,
            host: "localhost"
        )
    )
    
    /// 本模块的 ID，取自 DebugingModuleController 中记录的服务 ID 列表的第一个
    /// 仅在生产环境为开发或测试模式才生效
    static let moduleId = serviceIds.first!
    
    /// 该模块接受的来源服务的 ID
    ///
    /// 若有其他服务模块访问该模块，其 ServiceId 必须在以下白名单中，
    /// 且访问者的 serviceId != 被访问者的 serviceId，否则将会被拒绝连线
    /// 作为例子仅提供 6 个，你可以按需添加或减少
    static let serviceIds = [
        UUID(uuidString: "9D61FB39-D7EF-46B6-8690-4DDD23E561A4")!,
        UUID(uuidString: "F1ECC1D7-6E19-4F50-9B89-68FAA332B415")!,
        UUID(uuidString: "2AC424F7-F26A-4EA4-BE44-202ABC7CC514")!,
        UUID(uuidString: "74854475-1C1A-48E2-BAC9-E9C752942F88")!,
        UUID(uuidString: "C59C74DC-AF7F-4497-854B-75561D9FE995")!,
        UUID(uuidString: "F02F2803-BF88-4B51-A743-B3AA0F3FF804")!
    ]
    
    /// 模块管理器的访问链接，模块管理器登记了所有模块的信息
    /// 需要用于来源服务验证，作为测试，可走本地巡回路径
    /// 仅在生产环境为开发或测试模式才生效
    static let managerURL: URL = .init(string: "http://localhost")!
    
    /// 初始化你的 PostgreSQL 配置
    /// 这些参数仅在独立测试环境中可用
    /// 生产环境中将由 Whooshing 系统提供加密数据库
    ///
    /// 该配置设置 PostgreSQL 服务配置，而每个数据库服务中可有多个数据库，通过 dbParameters 进行设置
    ///
    /// fileStorageKey 用于文件加密系统的加密主密钥，为方便测试，硬编码至此。在生产环境中，这些均为无效
    /// 只有需要作为 FileStorage 的数据库才需要配置 fileStorageKey，若不设置则表示不支持在其上创建文件加密系统
    /// 作为测试目的，这些密钥可以重复
    static let dbServices: [Environment.DBService] = [
        .init(
            name: "default",
            host: "localhost",
            port: 5432,
            dbParameters: [
                .init(
                    name: "postgres",
                    user: "postgres",
                    password: "password"
                ),
                .init(
                    name: "privilege_module",
                    user: "postgres",
                    password: "password"
                ),
                .init(
                    name: "file_storage",
                    user: "postgres",
                    password: "password",
                    fileStorageKey: SendableSymmKey(
                        key: .init(
                            data: Data(base64Encoded: "UA/0Si+aUkrJou9W2pCDjrTkDBiAfZxdoD1MEFyHP58=")!
                        )
                    )
                )
            ]
        )
    ]
}

// MARK: - 以下为内部初始化代码，不要随意修改，除非你知道在做什么

extension DebuggingParameters {
    static func configData(dbServiceConfigs: [Environment.DBService] = []) -> Environment.Config{
        .init(
            id: moduleId,
            name: Woo.appName.lowercased(),
            port: port,
            dbServices: dbServiceConfigs,
            managerUrl: managerURL
        )
        .load(fileStorage: DebuggingParameters.fileStorageParas)
        .load(privilegeModule: DebuggingParameters.privilegeModuleParas)
    }
}

extension Woo {
    static let mode: Mode = {
        Mode.detect(testingAllowed ? DebuggingParameters.configData(dbServiceConfigs: DebuggingParameters.dbServices) : nil)
    }()
    
    private static let bootstrap: Bootstrap.Paras = {
        try! asyncToSync {
            try await Bootstrap.run(mode, driverKeys: Woo.driverKeys, logger: Self.logger.derive(subId: "app")).get()
        }
    }()

    static let nexus: Nexus = {
        try! asyncToSync {
            let tube = try await VaporTube.make(bootstrap).get()
            let nexus = Nexus(tube: tube, bootstrap: bootstrap)
            
            do {
                try await configure(nexus)
            } catch {
                nexus.logger.report(error: error)
                try? await nexus.asyncShutdown()
                throw error
            }
            return nexus
        }
    }()

    static func loggerBootstrap() {
        var factories: [LoggingFactory] = []
        
        factories.append(bootstrap.loggingFactory)
        
        let factory = LoggingFactory(factories: factories)
        if isIndependentDebug {
            factory.append(strategies: [.init(label: "console", level: .trace)]).bootstrap()
        } else {
            factory.bootstrap()
        }
    }

    static func main() async throws {
        loggerBootstrap()
        try await nexus.executeWithAsyncShutdown()
    }
}
