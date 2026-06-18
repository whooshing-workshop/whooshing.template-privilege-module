import Vapor
import WhooshingServer
import Fluent

func routes<T>(_ woo: Whooshing<T>, _ app: Application) throws where T: ServiceType {
    app.get { req async in
        "It works!"
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }
    
    try app.register(collection: UserController())
    try app.register(collection: FileController())
}
