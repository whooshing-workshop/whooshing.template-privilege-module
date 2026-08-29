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
}
