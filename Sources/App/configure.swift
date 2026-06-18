import Vapor
import WhooshingServer

struct Configuration {
    /// 数据库的迁移配置登记，用于初始化数据库的表结构
    /// 每个数据库可能被多个子服务所连接(inline, api, https)，但一个数据库一般应当仅初始化一次
    /// 避免多个子服务抢占初始化表结构
    /// Whooshing 系统将会为每个所配置的数据库调用该配置函数，以及该数据库被连接的子服务
    /// 保证所提供的数据库绝不重复，因此你可以在这里安全地分别为每个数据库登记迁移
    /// 这里登记了迁移并不会马上应用到真实数据库中，请见下一步 `migrationApply(in:)`
    static func migrationRegister(in database: Environment.DB, for services: [any WhooshingService]) async throws {
        if database.id.string == "default/postgres" {
            /// 作为示例，只对在 default 数据库服务中的 postgres 数据库进行初始化，
            /// 使用 database.id 做分辨，id 规则遵循 数据库服务名 + / + 数据库名
            /// 至于有哪些数据库请详见你的 `configure.yaml`(生产环境) 中 `pgsql` 下的配置，
            /// 或 `entrypoint.swift`(测试环境) 中 `Woo.dbServices` 下的配置
            /// 此处，default 数据库服务中的另一个数据库(file_storage)无需进行额外初始化
            /// FileStorage 模块会自行初始化
            services.first!.app.migrations.add(User.MIG(), to: database.id)
        }
    }
    
    /// 数据库迁移登记完成之后，将这些迁移应用到真实数据库中
    static func migrationApply(for service: any WhooshingService) async throws {
        // 第一次运行，若你的 PostgreSQL 服务中没有创建该表，则需要进行 autoMigrate
        // 此举将自动创建所需要的数据库表，一般来说只需运行一次即可，若表结构已经存在可注释这一行
        try await service.app.autoMigrate()
    }
    
    /// 对 Https 模块进行配置，如果设置了 HTTPS 环境变量
    /// 取决于 Package.swift 的 swiftSettings 中的环境变量设置
    static func https(_ woo: Whooshing<Https>, app: Application) async throws {
        try routes(woo, app)
    }
    
    /// 对 API 模块进行配置，如果设置了 API 环境变量
    /// 取决于 Package.swift 的 swiftSettings 中的环境变量设置
    static func api(_ woo: Whooshing<Api>, app: Application) async throws {
        try routes(woo, app)
    }
    
    /// 对 Inline 模块进行配置
    /// Inline 模块为每个服务模块的必须，因此不支持在 swiftSettings 中设置
    static func inline(_ woo: Whooshing<Inline>, app: Application) async throws {
        try routes(woo, app)
    }
}
