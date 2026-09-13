import Fluent
import VaporTube

/// 示例：模块自有的业务表 `users` 的增删查（**无鉴权**，仅作模板演示）。
///
///     GET    /users                  → [UserDTO]
///     GET    /users/find?email=      → UserDTO（不存在 → 400）
///     POST   /users/register         body: UserDTO → 200（邮箱唯一，重复 → 非 2xx）
///     DELETE /users/:email           → 204（不存在 → 400）
///
/// 生产模块中这类接口应当挂到 `apiProtected` 分组下并登记 `.privilege(...)`。
struct UserController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {
        let users = routes.grouped("users")
        
        users.get(use: getAllUsers)
        users.get("find", use: find)
        users.post("register", use: addUser)
        users.delete("delete", use: deleteUser)
        users.group(":email") { user in
            user.delete(use: deleteUser)
        }
    }
    
    @Sendable
    func find(req: Request) async throws -> UserDTO {
        let email = try req.query.get(String.self, at: "email")
        guard let user = try await User.query(on: req.db).filter(\.$email == email).first() else { throw Abort(.badRequest, reason: "用户不存在") }
        return UserDTO(email: user.email, age: user.age)
    }
    
    @Sendable
    func getAllUsers(req: Request) async throws -> [UserDTO] {
        return try await User.query(on: req.db).all().map { user in
            UserDTO(email: user.email, age: user.age)
        }
    }
    
    @Sendable
    func addUser(req: Request) async throws -> HTTPStatus {
        let userDTO = try req.content.decode(UserDTO.self)
        let user = User(email: userDTO.email, age: userDTO.age)
        try await user.save(on: req.db)
        return .ok
    }
    
    @Sendable
    func deleteUser(req: Request) async throws -> HTTPStatus {
        guard let email = req.parameters.get("email") else { throw Abort(.badRequest, reason: "参数不正确") }
        guard let user = try await User.query(on: req.db).filter(\.$email == email).first() else { throw Abort(.badRequest, reason: "用户不存在") }
        try await user.delete(on: req.db)
        return .noContent
    }
    
}
