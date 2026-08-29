import VaporTube
import PrivilegeModuleDriver

public func configure(_ nexus: Nexus<VaporTube>) async throws {
    nexus.tube.app.migrations.add(User.MIG(), to: nexus.config.dbServices[0].dbs[0].id)
    try routes(nexus)
    // 仅在测试或开发环境下，才会加载其中的 Debuging 路由
    // 正式发布可删除这段代码
    if Woo.isIndependentDebug {
        // 用于模拟 Manager 模块的服务模块 ID 验证 API
        try nexus.tube.app.register(collection: DebugingModuleController(serviceIds: DebuggingParameters.serviceIds))
    }
}
