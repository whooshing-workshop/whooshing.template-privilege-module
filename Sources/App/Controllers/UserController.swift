import Fluent
import Vapor

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
