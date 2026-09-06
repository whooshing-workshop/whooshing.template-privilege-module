import Fluent
import VaporTube
import PrivilegeModuleDriver

func routes(_ nexus: Nexus<VaporTube>) throws {
    nexus.tube.app.get { req async in
        "It works!"
    }

    nexus.tube.app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    try nexus.tube.app.register(collection: UserController())
    try nexus.tube.app.register(collection: FileController())
    
    // 用于服务间通讯的路由
    // 该路由将会先确认来源服务是合法的，否则拒绝连接
    let inlineProtected = nexus.tube.app.inlineProtectGrouped()
    inlineProtected.get("test") { req async throws -> String in
        let id = try req.auth.require(ServiceValidator.Identifier.self)
        return id.incomingId.uuidString
    }
    
    // 用于需要用户身份验证的路由
    // 该路由将会先确认用户是否是合法的，否则拒绝连线
    let apiProtected = nexus.tube.app.apiProtectGrouped(in: nexus).arbitratorGrouped(in: nexus, on: .module)
    
    apiProtected.get("user_required") { req async throws in
        try req.auth.require(AuthData.self)
    }.privilege {
        $0.allow { $0.user.email == "wangchenlin2001@icloud.com" }
    }
    
    apiProtected.get("role_required") { req async throws in
        try req.auth.require(AuthData.self)
    }.privilege {
        $0.allow { $0.role.name == "admin" }
    }
    
    apiProtected.get("no_protect") { req async throws in
        try req.auth.require(AuthData.self)
    }.privilege(by: .allowAll)
}
