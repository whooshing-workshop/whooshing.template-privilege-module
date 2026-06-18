// swift-tools-version:6.3
import PackageDescription

// 设置该 Whooshing 服务模块的子模块
// 指定某个环境变量，则需要在 configure.swift 中实现相关的配置函数
// 可设置 .https 和 .api 两个
let WhooshingModules: [WhooshingModuleType] = [
    .https,
    .api
]

enum WhooshingModuleType: String {
    case https = "HTTPS"
    case api = "API"
}

let package = Package(
    name: "whooshing.template-privilege-module",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    dependencies: [
        // 💧 Vapor -- Swift 服务器端第三方框架
        .package(url: "https://github.com/whooshing-workshop/whooshing-vapor.git", from: "1.1.2"),
        // 🪩 Whooshing 基本工具
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-basic.git", from: "1.5.10"),
        // ⭐️ Whooshing 服务模块系统
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-server.git", from: "1.2.5"),
        // 🗄 PostgreSQL 数据库的 ORM(对象关系映射)
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-pgsql.git", from: "1.0.10"),
        // 📁 Whooshing 文件加密系统模块
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-file-storage", from: "1.0.6"),
        // 📁 Whooshing 文件加密系统模块驱动
        .package(url: "https://github.com/whooshing-workshop/whooshing.driver-file-storage.git", from: "1.0.4"),
        // 🪩 Whooshing 权限系统模块
        .package(url: "https://github.com/whooshing-workshop/whooshing.toolbox-privilege-system", from: "1.0.0"),
        // 🪩 Whooshing 权限系统模块驱动
        .package(url: "https://github.com/whooshing-workshop/whooshing.driver-privilege-system.git", from: "1.0.0"),
        // 🔵 Swift 高性能网络通讯模块
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Vapor", package: "whooshing-vapor"),
                .product(name: "PgSQL", package: "whooshing.toolbox-pgsql"),
                .product(name: "Cryptos", package: "whooshing.toolbox-basic"),
                .product(name: "ErrorHandle", package: "whooshing.toolbox-basic"),
                .product(name: "WhooshingServer", package: "whooshing.toolbox-server"),
                .product(name: "FileStorage", package: "whooshing.toolbox-file-storage"),
                .product(name: "FileStorageDriver", package: "whooshing.driver-file-storage"),
                .product(name: "PrivilegeModule", package: "whooshing.toolbox-privilege-system"),
                .product(name: "PrivilegeModuleDriver", package: "whooshing.driver-privilege-system")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "whooshing-vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ],
    swiftLanguageModes: [.v5]
)

var swiftSettings: [SwiftSetting] {
    [
        .enableUpcomingFeature("DisableOutwardActorInference"),
        .enableExperimentalFeature("StrictConcurrency")
    ] +
    WhooshingModules.map { SwiftSetting.define($0.rawValue) }
}
