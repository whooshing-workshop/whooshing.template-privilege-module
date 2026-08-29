import Fluent
import FileStorage
import VaporTube
import Foundation

struct FileAttributes: Content {
    let data: Data
    let path: StoragePath
}

struct FileController: RouteCollection {
    
    func boot(routes: any RoutesBuilder) throws {
        let file = routes.grouped("file")
        file.put(use: fileStore)
        file.delete(use: fileDelete)
        file.post(use: fileRead)
    }
    
    @Sendable
    func fileStore(req: Request) async throws -> StoragePath {
        let fileAttributes = try req.content.decode(FileAttributes.self)
        let file = try await FileStorage.default.createFile(at: fileAttributes.path, withIntermediateDirectories: true)
        try await file.withWriter { writer in
            try await writer.write(at: .begin(), bytes: fileAttributes.data, method: .insert)
        }
        return fileAttributes.path
    }
    
    @Sendable
    func fileDelete(req: Request) async throws -> StoragePath {
        let filePath = try req.content.decode(StoragePath.self)
        let file = try await FileStorage.default.getFile(at: filePath)
        try await file.delete(force: true)
        return filePath
    }
    
    @Sendable
    func fileRead(req: Request) async throws -> Data {
        let filePath = try req.content.decode(StoragePath.self)
        let file = try await FileStorage.default.getFile(at: filePath)
        let reader = try await file.openForRead()
        defer {
            Task {
                do {
                    try await reader.close()
                } catch {
                    fatalError("文件读取子关闭失败: \(error)")
                }
            }
        }
        let data = try await reader.readData(part: .all)
        return data
    }
    
}
