import PgSQL
import Foundation

// 实现协议 PGModel
final class User: PGModel, @unchecked Sendable {

    // 设置表的名称，请注意不要与其他类型的表冲突
    static let name = "users"

    // 定义该表的所有字段信息，详见 PGFields 协议
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                           .primary
        let email = PGField("email", .string)                   .required.unique.def("null@null.com")
        let age = PGField("age", .int)                          .def(30)
        let createdAt = PGField("create_at", .datetime)
        let updateAt = PGField("update_at", .datetime)          .def("2001-02-27")
    }
    
    // 生成字段信息实例
    static let fields = Fields()
    
    // 以下关于键值绑定的 @ID, @Field, @Timestamp 等等属性包装器，可参见 [Vapor 官方文档](https://docs.vapor.codes/fluent/model/)

    // 将数据库表 users 中的 id 字段绑定到该模型的 id 属性
    @ID(key: .id)                                                   var id: UUID?
    // 将数据库表 users 中的 email 字段绑定到该模型的 email 属性
    @Field(fields.email)                                            var email: String
    // 将数据库表 users 中的 age 字段绑定到该模型的 age 属性
    @Field(fields.age)                                              var age: Int
    // 将数据库表 users 中的 create_at 字段绑定到该模型的 createAt 属性
    @Timestamp(fields.createdAt, on: .create)                       var createdAt: Date?
    // 将数据库表 users 中的 update_at 字段绑定到该模型的 updateAt 属性
    @Timestamp(fields.updateAt, on: .update)                       var updatedAt: Date?
    
    // 数据库表结构生成和迁移，负责与数据库交互，进行表创建，迁移，恢复等等交涉
    // 你需要确保 typealias DataModel = User 中，DataModel 正确地指向你的表数据模块
    // 在此例中指向为 User
    struct MIG: PGMigration, Sendable {
        typealias DataModel = User
        /// 是否启动 TDE 加密，这里根据环境判断，若是独立测试模式，则不进行加密(测试机器中一般没有 percona pg_tde 环境)
        var tdeEncrypt: Bool {
            !Woo.isIndependentDebug
        }
    }
}

// 以上便完全实现了 PGModel 协议
// 若你愿意，你可以添加一些其他的功能
extension User {
    convenience init(email: String, age: Int) {
        self.init()
        self.email = email
        self.age = age
    }
}
