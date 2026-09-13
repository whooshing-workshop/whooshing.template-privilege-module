import Fluent
import VaporTube
import PrivilegeModuleDriver

/// 路由总表
///
/// | 分组 | 前缀 | 保护链 | 说明 |
/// |---|---|---|---|
/// | 示例 | `/`, `/hello`, `/users/*`, `/file` | 无 | 模板示例路由 |
/// | 服务间 | `/inline` | `ServiceValidator`（X-Module-ID 必须为已登记的其它模块） | 供其它服务模块调用 |
/// | 受保护 API | `/api` | `ApiValidator(.remote)` → `AuthData.guard` → `Arbitrator(.remote)` | 面向终端用户 |
///
/// 受保护 API 的完整流程：
///   1. `ApiValidator` 读取 `X-Credential` / `X-Encrypted-Token` / `X-Role-Id`，转发权限主系统 `POST /inline/authenticate`，
///      成功后把 `AuthData { key, token(user), role }` 登录到 `req.auth`；
///   2. `Arbitrator` 取出路由上通过 `.privilege(...)` 登记的资源（`RouterResource`）与操作（`run`），
///      连同本模块数据库中该资源绑定的 privilege ID，转发权限主系统 `POST /inline/arbitrate`；
///      结果 = 角色策略(本模块) AND 用户全部域的策略(本模块) AND 路由 privilege 策略；任一为 false → 401。
///
/// `.privilege { $0.allow { ... } }` 中的闭包参数是 **privilege 策略** 的 input 镜像（`PrivilegePolicyInput`），
/// 可访问 `privilegeId / operation / user / role / resource`（toolbox ≥ V1.1.0.14 起仲裁 input 含 `role` 对象），
/// 因此 `role_required` 可以直接写 `$0.role.name == "admin"`。
/// 注意 privilege 策略只是 AND 中的一项：即便它放行，该角色仍须在本模块下至少有一条角色策略，
/// 否则权限主系统会以“角色无策略”拒绝（toolbox ≥ V1.1.1.8），模块响应 401。
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

    /// 仅允许特定邮箱的用户：以 privilege 策略表达（仲裁 input.user.email）
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
