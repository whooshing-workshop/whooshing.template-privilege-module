import Vapor

/// 创建一个 DTO，用于解包或编码请求中的数据
/// 将 HTTP 请求中对方发来的数据转为该 Swift 类型
struct UserDTO: Content, Equatable {
    let email: String
    let age: Int
    
    init(email: String, age: Int) {
        self.email = email
        self.age = age
    }
}

extension User {
    func toDTO() -> UserDTO {
        .init(email: self.email, age: self.age)
    }
}
