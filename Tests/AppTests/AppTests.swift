@testable import App
import VaporTesting
import Testing
import Fluent
import FileStorage
import FileStorageDriver
import WhooshingServer

@Suite("App Tests with DB", .serialized)
struct AppTests {
    private func withApp(_ test: (Whooshing<Https>, Application) async throws -> ()) async throws {
        let logger = Logger(label: "testing")
        let bootstrap = try await Whooshing<Https>.bootstrap(
            .testing(DebuggingParameters.httpsDebuggingData(dbServiceConfigs: Woo.dbServices)),
            driverKeys: DebuggingParameters.driverKeys,
            logger: logger
        ).get()
        let woo = try await Whooshing.make(bootstrap).get()
        do {
            try await Configuration.https(woo, app: woo.app)
            for db in woo.databases {
                try await Configuration.migrationRegister(in: db, for: [woo])
            }
            try await woo.app.autoMigrate()
            try await test(woo, woo.app)
            try await woo.app.autoRevert()
        } catch {
            try? await woo.app.autoRevert()
            try await woo.asyncShutdown().get()
            throw error
        }
        try await woo.asyncShutdown().get()
    }
    
    @Test("Test Hello World Route")
    func helloWorld() async throws {
        try await withApp { woo, app in
            try await app.testing().test(.GET, "hello") { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Hello, world!")
            }
        }
    }
    
    @Test("Getting all the Users")
    func getAllUsers() async throws {
        try await withApp { woo, app in
            let sampleUsers = [User(email: "email1@example.com", age: 20), User(email: "email2@example.com", age: 21)]
            try await sampleUsers.create(on: app.db)
            
            try await app.testing().test(.GET, "users") { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([UserDTO].self) == sampleUsers.map { $0.toDTO() } )
            }
        }
    }
    
    @Test("Creating a User")
    func createUser() async throws {
        let newDTO = UserDTO(email: "email1@example.com", age: 20)
        
        try await withApp { woo, app in
            try await app.testing().test(.POST, "users/register", beforeRequest: { req in
                try req.content.encode(newDTO)
            }) { res async throws in
                #expect(res.status == .ok)
                let models = try await User.query(on: app.db).all()
                #expect(models.map({ $0.toDTO() }) == [newDTO])
            }
        }
    }
    
    @Test("Deleting a User")
    func deleteUser() async throws {
        let testUsers = [User(email: "email1@example.com", age: 20), User(email: "email2@example.com", age: 21)]
        
        try await withApp { woo, app in
            try await testUsers.create(on: app.db)
            
            try await app.testing().test(.DELETE, "users/\(testUsers[0].email)") { res async throws in
                #expect(res.status == .noContent)
                let userShouldNotExist = try await User.query(on: app.db).filter(\.$email == testUsers[0].email).first()
                #expect(userShouldNotExist == nil)
            }
        }
    }
    
    static let file = FileAttributes(data: .random(size: 100), path: "storage/files/example.txt")
    
    @Test("Store a File")
    func storeFile() async throws {
        try await withApp { woo, app in
            try await app.testing().test(.PUT, "file", beforeRequest: { req in
                try req.content.encode(Self.file)
            }) { res in
                #expect(res.status == .ok)
                let path = try res.content.decode(StoragePath.self)
                #expect(Self.file.path == path)
            }
        }
    }
    
    @Test("Read a File")
    func readFile() async throws {
        try await withApp { woo, app in
            try await app.testing().test(.POST, "file", beforeRequest: { req in
                try req.content.encode(Self.file.path)
            }) { res in
                #expect(res.status == .ok)
                let data = try res.content.decode(Data.self)
                #expect(Self.file.data == data)
            }
        }
    }
    
    @Test("Delete a File")
    func deleeteFile() async throws {
        try await withApp { woo, app in
            try await app.testing().test(.DELETE, "file", beforeRequest: { req in
                try req.content.encode(Self.file.path)
            }) { res in
                #expect(res.status == .ok)
                let path = try res.content.decode(StoragePath.self)
                #expect(Self.file.path == path)
            }
        }
    }
}

extension Data {
    static func random(size: Int) -> Data {
        guard size > 0 else { return Data() }
        var data = Data(count: size)
        var rng = SystemRandomNumberGenerator()
        data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            for i in 0..<size {
                buffer[i] = UInt8.random(in: 0...255, using: &rng)
            }
        }
        return data
    }

}
