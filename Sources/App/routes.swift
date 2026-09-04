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
    let inlineProtected = nexus.tube.app.grouped("inline").grouped(ServiceValidator(), ServiceValidator.Identifier.guardMiddleware())
    inlineProtected.get("test") { req async throws -> String in
        let id = try req.auth.require(ServiceValidator.Identifier.self)
        return id.incomingId.uuidString
    }
    
    // 用于需要用户身份验证的路由
    // 该路由将会先确认用户是否是合法的，否则拒绝连线
    let apiProtected = nexus.tube.app.grouped("api").apiProtectGrouped(in: nexus)
    apiProtected.get("test") { req async throws in
        try req.auth.require(AuthData.self)
    }
}
