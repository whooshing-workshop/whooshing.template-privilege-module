# Whooshing 权限业务模块模版
基于 [Vapor](https://vapor.codes/) 以及 [Nexus](https://github.com/whooshing-workshop/whooshing.nexus) / [VaporTube](https://github.com/whooshing-workshop/whooshing.tube-vapor) 构建的服务模块模版，并预先接入了 **文件加密存储** 与 **权限模块（PrivilegeModule）**。

用于快速初始化一个受 Whooshing 权限系统保护的业务服务模块：模块内的路由可以直接声明自己所保护的资源与策略，启动时自动同步至权限数据库，请求时自动完成用户身份验证与权限仲裁，且支持不依赖任何外部模块的独立开发环境测试。

已集成以下 Whooshing 核心库：

- [whooshing.tube-vapor](https://github.com/whooshing-workshop/whooshing.tube-vapor)（含 [whooshing.nexus](https://github.com/whooshing-workshop/whooshing.nexus)）
- [whooshing.driver-privilege-system](https://github.com/whooshing-workshop/whooshing.driver-privilege-system)（`PrivilegeModuleDriver`）
- [whooshing.driver-file-storage](https://github.com/whooshing-workshop/whooshing.driver-file-storage)
- [whooshing.toolbox-privilege-system](https://github.com/whooshing-workshop/whooshing.toolbox-privilege-system)
- [whooshing.toolbox-file-storage](https://github.com/whooshing-workshop/whooshing.toolbox-file-storage)
- [whooshing.toolbox-basic](https://github.com/whooshing-workshop/whooshing.toolbox-basic)

本项目高度依赖 [Vapor](https://vapor.codes/)，另请参阅 [Vapor 官方文档](https://docs.vapor.codes/)

--------

### 项目简介

通过少量配置即可启动开发、调试与部署。另见 [whooshing.nexus](https://github.com/whooshing-workshop/whooshing.nexus)

支持构建独立的业务服务模块，可与 Whooshing 系统中的权限主系统（[whooshing.module-privilege-system](https://github.com/whooshing-workshop/whooshing.module-privilege-system)）及其他模块无缝对接，默认集成：

- ✅ Vapor 启动框架与 Nexus 服务模块创建机制
- ✅ 环境变量自动识别与配置切换（生产 / 开发 / 测试）
- ✅ Debug 配置与模块测试数据（测试用户、角色、凭据白名单）
- ✅ 文件加密存储模块（`FileStorage.default`）
- ✅ 权限模块（`PrivilegeModule.module`），资源与策略随路由声明，启动时自动注册
- ✅ 用户身份验证（`/api`）、权限仲裁与服务间来源校验（`/inline`）三类受保护路由组
- ✅ 以 Swift DSL 编写 OPA 策略（`PrivilegePolicy`）

------

### 快速开始

1. **克隆本模版项目**

   ```sh
   git clone https://github.com/whooshing-workshop/whooshing.template-privilege-module.git MyService
   cd MyService
   ```

2. **修改模块名称 (可选)**

   修改 [Package.swift](Package.swift) 的 name 字段来命名你的模块：

   ```swift
   name: "whooshing.my-service"
   ```

   同时修改 [pm2.config.json](pm2.config.json) 与 [configure.yaml](configure.yaml) 中的模块名称，确保与 Package 的名称相同

   ```json
   "name": "whooshing.template-privilege-module"
   ```

   以及 [entrypoint.swift](Sources/App/entrypoint.swift) 的 `enum Woo` 声明中的 `appName`:

   ```swift
   /// 该服务模块的名称
   static let appName = "App"
   ```

   此处的名称用于各类相关资源的标识（如日志 label、文件存储路径），并不会作为服务名称展示

3. **准备外部依赖**

   独立调试模式需要本机运行：

   * **PostgreSQL**（默认 `localhost:5432`，用户 `postgres` / 密码 `password`），并预先创建 `postgres`、`privilege_module`、`file_storage` 三个数据库
   * **EOPA / OPA**（默认 `http://localhost:8181`），用于权限仲裁

4. **调整调试参数**

   在 [entrypoint.swift](Sources/App/entrypoint.swift) 的 `DebuggingParameters` 中调整数据库、文件存储与权限模块的连接参数：

   ```swift
   /// 服务监听的端口号
   static let port = 6500

   /// 文件加密存储：加密文件默认保存在 ~/app_file_storage
   static let fileStorageParas = Environment.FS(
       dir: URL.homeDirectoryURL.appending(component: "app_file_storage")
   )

   /// 权限模块：EOPA 连接参数、API 身份验证策略与仲裁策略
   static let privilegeModuleParas = Environment.PM(
       eopa: .init(scheme: .http, port: 8181, host: "localhost"),
       apiStrategy: DebuggingDatas.apiValidateStrategy,
       arbitrateStrategy: DebuggingDatas.arbitrateStrategy
   )

   /// PostgreSQL 服务，可包含多个数据库；只有作为 FileStorage 索引库的数据库需要 fileStorageKey
   static let dbServices: [Environment.DBService] = [
       .init(
           name: "default",
           host: "localhost",
           port: 5432,
           dbParameters: [
               .init(name: "postgres", user: "postgres", password: "password"),
               .init(name: "privilege_module", user: "postgres", password: "password"),
               .init(
                   name: "file_storage",
                   user: "postgres",
                   password: "password",
                   fileStorageKey: SendableSymmKey(key: .init(data: Data(base64Encoded: "UA/0Si+aUkrJou9W2pCDjrTkDBiAfZxdoD1MEFyHP58=")!))
               )
           ]
       )
   ]
   ```

   **这些参数仅在独立测试环境中被使用，生产环境中所有配置均由 Whooshing 系统通过环境变量提供**

5. **调整调试数据**

   `DebuggingDatas` 中定义了独立调试时使用的测试用户、角色、凭据白名单与来源服务白名单：

   ```swift
   /// API 身份验证策略：
   ///   .debuging(whitelist:)  用白名单直接验证凭据与加密 Token（默认）
   ///   .remote(authURL:)      转发至权限主系统进行验证，如 http://localhost:6501
   static let apiValidateStrategy: ApiValidator.Strategy = .debuging(whitelist: apiAuthenticates)

   /// 权限仲裁策略：
   ///   .debuging(mocking:)    自定义闭包决定是否放行（默认永远放行）
   ///   .remote(arbiURL:)      转发至权限主系统进行仲裁
   static let arbitrateStrategy: ArbitrateStrategy = .debuging { req, resource, operation in true }

   /// 允许访问 /inline 路由的来源模块 ID 白名单
   static let serviceIds = [ ... ]
   ```

   > **与权限主系统联调 / 跑集成测试时必须把两个策略都改为 `.remote(...)`**：
   >
   > ```swift
   > static let apiValidateStrategy: ApiValidator.Strategy = .remote(authURL: .init(string: "http://localhost:6501")!)
   > static let arbitrateStrategy: ArbitrateStrategy = .remote(arbiURL: .init(string: "http://localhost:6501")!)
   > ```
   >
   > 默认的 `.debuging` 白名单模式**不会**把凭据转发到权限主系统，只认 `apiAuthenticates` 里写死的两个账号；其它任何用户访问 `/api/*` 都会得到 `401 [Debug] 凭据或 Token 未在白名单中`。[whooshing.integration-tests](https://github.com/whooshing-workshop/whooshing.integration-tests) 会自动识别这种情况并跳过端到端用例。

6. **定义资源与权限模块**

   在 [Drivers/PrivilegeModule.swift](Sources/App/Drivers/PrivilegeModule.swift) 中声明本模块的资源类型清单与资源结构：

   ```swift
   /// 资源类型清单，每种类型对应一个 @Resource 类型
   enum ResourceList: String, ResourceTypeList {
       case file
       case router
   }

   @Resource
   struct FileResource {
       typealias ResourceType = ResourceList
       static let type: ResourceList = .file

       let appId: String
       let path: String

       enum Operations: String, OperationList {
           case read
           case write
       }
   }

   /// 权限模块全局单例，使用 "default" 服务中的 "privilege_module" 数据库
   extension PrivilegeModule<ResourceList> {
       static let module: PrivilegeModule<ResourceList> = {
           Woo.nexus.syncMakePrivilegeModule(
               for: db(name: "privilege_module", from: "default"),
               logger: Woo.logger,
               debugging: Woo.isIndependentDebug
           )
       }()
   }
   ```

   同文件中还为 `Route` 提供了 `privilege(...)` 便捷扩展，可直接以 `PrivilegePolicy` DSL 为路由声明策略（见下文「路由测试」）

7. **文件加密系统配置**

   在 [Drivers/FileStorage.swift](Sources/App/Drivers/FileStorage.swift) 中调整文件系统的配置：

   ```swift
   extension FileStorage {
       /// 默认文件存储模块，加密文件存于 "default" 文件夹下，索引存于 "default/file_storage" 数据库
       static let `default`: FileStorage = {
           Woo.nexus.syncMakeFileStorage(
               for: db(name: "file_storage", from: "default"),
               storagePath: "default",
               logger: Woo.logger,
               dirCreateAction: .createIfNeed(withIntermediateDirectories: true),
               debugging: Woo.isIndependentDebug
           )
       }()
   }
   ```

   > 需要调用时使用 `FileStorage.default` 或 `req.fileStorage` 即可，关于 `FileStorage` 请详见 [whooshing.toolbox-file-storage](https://github.com/whooshing-workshop/whooshing.toolbox-file-storage)

8. **配置数据库迁移与路由**

   在 [configure.swift](Sources/App/configure.swift) 中登记数据库迁移、注册路由，以及仅在独立调试下加载的 Manager 模拟路由：

   ```swift
   public func configure(_ nexus: Nexus<VaporTube>) async throws {
       nexus.tube.app.migrations.add(User.MIG(), to: nexus.config.dbServices[0].dbs[0].id)
       try routes(nexus)
       if Woo.isIndependentDebug {
           try nexus.tube.app.register(collection: DebugingModuleController(serviceIds: DebuggingDatas.serviceIds))
       }
   }
   ```

9. **模块配置**

   在 [configure.yaml](configure.yaml) 中根据你的需求进行配置

   > 关于具体的配置细节，请详细参照其中的注释文档

10. **运行项目**

    首次运行先执行数据库迁移（示例 `users` 表；未迁移时 `POST /users/register` 会 500）：

    ```sh
    swift run App migrate --env development
    ```

    然后使用 Xcode 或命令行运行：

    ```sh
    swift run App serve --env development
    ```

    或指定环境：

    ```sh
    swift run App serve --env production
    ```

    Xcode 启动默认即为开发环境 (development)。将 `Woo.testingAllowed` 设为 `false` 可禁止模块进入独立调试 / 测试模式

    > 在 [entrypoint.swift](Sources/App/entrypoint.swift) 的 `DebuggingDatas` 中定义了默认的测试用户、角色、凭据等调试数据，实际部署时应替换或禁用调试代码。
    >
    > 具体的调试细节，请参见文档注释

------

### 项目结构预览

```
├── Package.swift                    // Swift Package 描述文件
├── configure.yaml                   // Whooshing 系统部署配置
├── pm2.config.json                  // pm2 进程配置
├── Sources/App
│   ├── entrypoint.swift             // 项目入口、运行模式识别、调试参数与调试数据
│   ├── configure.swift              // 数据库迁移登记、路由注册
│   ├── routes.swift                 // 路由定义（含 /inline、/api 受保护路由组）
│   ├── Drivers
│   │   ├── DriverInits.swift        // 驱动预热
│   │   ├── FileStorage.swift        // 文件加密存储单例
│   │   └── PrivilegeModule.swift    // 资源类型清单、资源定义、权限模块单例与 Route 扩展
│   ├── Controllers                  // 示例控制器
│   ├── Models                       // Fluent 模型
│   └── DTOs                         // 数据传输对象
└── Tests/AppTests                   // 测试代码
```

--------

### 路由测试

模版项目默认包含简单的测试路由：

```swift
GET /
返回 "It works!"

GET /hello
返回 "Hello, world!"
```

以及两个示例控制器 `FileController` 与 `UserController`：

```swift
FileController 提供（StoragePath 在 JSON 中为路径组件数组，如 ["docs", "a.txt"]）:
    - PUT    /file: 存储文件，Body { data: Base64, path: StoragePath }
    - DELETE /file: 删除文件，Body StoragePath
    - POST   /file: 读取文件，Body StoragePath，返回文件内容

UserController 提供:
    - GET    /users: 列出所有用户
    - GET    /users/find?email=: 查找用户
    - POST   /users/register: 注册用户
    - DELETE /users/delete: 删除用户
    - DELETE /users/<email>: 通过用户的 email 删除用户
```

`routes.swift` 中还演示了三类受保护路由：

```swift
// 服务间通讯：请求头需携带合法的 X-Module-ID
let inlineProtected = nexus.tube.app.inlineProtectGrouped()
inlineProtected.get("test") { req async throws -> String in
    try req.auth.require(ServiceValidator.Identifier.self).incomingId.uuidString
}

// 用户身份验证 + 权限仲裁：请求头需携带 X-Credential、X-Encrypted-Token 与 X-Role-Id
let apiProtected = nexus.tube.app
    .apiProtectGrouped(in: nexus)
    .arbitratorGrouped(in: nexus, on: .module)

// 用 PrivilegePolicy DSL 声明该路由的访问策略，启动时会自动注册为资源与权限
apiProtected.get("user_required") { req async throws in
    try req.auth.require(AuthData.self)
}.privilege {
    $0.allow { $0.user.email == "someone@example.com" }
}

// 需要特定角色：仲裁 input 含 role 对象（toolbox ≥ V1.1.0.14），可直接在 privilege 策略中引用 $0.role
// 注意：即便这里放行，该角色仍须在本模块下至少配置一条角色策略，否则仲裁会因“角色无策略”被拒
apiProtected.get("role_required") { req async throws in
    try req.auth.require(AuthData.self)
}.privilege {
    $0.allow { $0.role.name == "admin" }
}

apiProtected.get("no_protect") { req async throws in
    try req.auth.require(AuthData.self)
}.privilege(by: .allowAll)
```

> 声明了 `.privilege(...)` 的路由会被 `ResourceAutoRegister` 在应用启动后自动同步至权限数据库：旧资源与权限被清理，新资源、权限及其绑定关系被重建。路由资源的 `appId` 为稳定的 `"<METHOD> /<path>"`（如 `"GET /api/no_protect"`，同一路由多次登记依次追加 `#1`、`#2`…），可在权限主系统的角色 / 域策略中以 `input.resource.appId` 精确引用，例如 `allow if { input.resource.appId == "GET /api/no_protect" }`。关于策略 DSL 与仲裁 input 的完整结构，请见 [whooshing.toolbox-privilege-system](https://github.com/whooshing-workshop/whooshing.toolbox-privilege-system)

#### 受保护路由的仲裁结果

`/api/*` 请求经 `ApiValidator(.remote)` 认证后，由 `Arbitrator(.remote)` 向权限主系统 `POST /inline/arbitrate`，结果为：

```
角色在本模块下的全部策略 AND 用户所有域（直接 / 群组 / 祖先群组）在本模块下的策略 AND 路由 privilege 策略
```

任一为 false、角色在本模块下没有任何策略、或主系统返回错误，模块统一响应 **401**。因此给一个新角色开放本模块的访问，至少要在权限主系统为它创建一条本模块（`module_id` = 本模块 ID）的角色策略，例如 `allow if { true }` 或按 `input.operation` / `input.resource.appId` 细分。

-------

### 单元测试支持

项目已包含测试目标，可在 AppTests 中添加 Vapor 路由测试：

```sh
swift test
```

-----

### 运行环境

* **macOS** (> 13.0)
* **iOS** (> 16.0)
* **Linux** (> 20)
* **Swift** (> 6.3)
* **watchOS** (> 6.0) **[未测试]**
* **tvOS** (> 13) **[未测试]**

-------

### 联系与反馈

如有使用问题或建议，请通过 [GitHub Issues](https://github.com/whooshing-workshop/whooshing.template-privilege-module/issues) 提交反馈。

或发至邮箱 [contact@official.whooshings.space](mailto:contact@official.whooshings.space)
