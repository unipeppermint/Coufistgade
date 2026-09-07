//
//  LaunchLinkService.swift
//  coufistgade
//
//  启动时问一次服务端：有没有要打开的网页。有就交给 WebViewController，没有就
//  照常进游戏。
//
//  三条设计约束，都是为了「这个功能坏掉时游戏不受影响」：
//
//  1. **失败即放行。** 超时、断网、返回垃圾、返回空——一律当作「没有链接」，
//     绝不阻断启动。这类远程开关最常见的事故是服务端挂了把 app 一起锁死。
//  2. **只认 https。** 见 `Self.validate(_:)`。ATS 本来就会拦 http，但拦的是
//     加载那一刻；在这里就拒掉，可以让 javascript:、data:、file: 这些根本进不
//     到 WKWebView 里。
//  3. **只发送固定应用标识。** 请求体中的 username 固定为配置值，不读取用户
//     资料，也不采集游戏数据。
//
//  不碰 Firebase：这是一次普通的 HTTPS POST，用 URLSession 就够，没有理由为它
//  引入 Remote Config。
//

import Foundation

/// 启动链接的来源。抽成协议只为了测试能塞一个假的进来，生产只有一个实现。
protocol LaunchLinkFetching: Sendable {
    func fetchLink() async -> URL?
}

final class LaunchLinkService: LaunchLinkFetching {

    enum Configuration {
        /// 启动链接接口与 username 都是产品协议的一部分，不从运行时数据读取。
        static let endpoint = URL(string: "https://pfhcdyh.top/v2/api/user/login")!
        static let username = "com.xkeso.baopvestor"

        /// 请求超时。
        ///
        /// 压得比 URLSession 默认的 60 秒短得多：这个请求挡在启动路径上，用户
        /// 盯着的是一个还没开始的游戏。宁可放弃这次链接，也不让人等。
        static let timeout: TimeInterval = 5

        /// 响应体大小上限。超过就当作无效——正常的响应是几十字节的 JSON，
        /// 大出量级说明拿到的不是我们要的东西。
        static let maximumResponseBytes = 64 * 1024

        /// 允许的协议。只有 https。
        static let allowedSchemes: Set<String> = ["https"]
    }

    private struct RequestBody: Encodable {
        let username: String
    }

    private struct ResponseBody: Decodable {
        let code: Int
        let data: ResponseData
    }

    private struct ResponseData: Decodable {
        let path: String
    }

    private let session: URLSession
    private let endpoint: URL
    private let username: String?

    /// - Parameters:
    ///   - endpoint: 覆盖生产端点，测试用。
    ///   - username: 覆盖生产环境的固定 username，测试用。
    ///   - session: 覆盖默认 session，测试用。
    init(
        endpoint: URL = Configuration.endpoint,
        username: String? = Configuration.username,
        session: URLSession? = nil
    ) {
        self.endpoint = endpoint
        self.username = username

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = Configuration.timeout
            configuration.timeoutIntervalForResource = Configuration.timeout
            // 不缓存：这是个开关，读到旧值比读不到更糟。
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }
}

// MARK: - 取链接

extension LaunchLinkService {

    /// 问一次服务端。没有链接、或任何一步出错，都返回 nil。
    ///
    /// 不 throw：调用方对「为什么没有」无能为力，能做的只有照常启动。错误只在
    /// DEBUG 下打日志。
    func fetchLink() async -> URL? {
        guard let username = username?.trimmingCharacters(in: .whitespacesAndNewlines),
              !username.isEmpty else {
            #if DEBUG
            print("[LaunchLink] 缺少 username，已跳过请求。")
            #endif
            return nil
        }

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = Configuration.timeout
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(RequestBody(username: username))

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else { return nil }
            guard (200..<300).contains(http.statusCode) else {
                #if DEBUG
                print("[LaunchLink] HTTP \(http.statusCode)，忽略。")
                #endif
                return nil
            }
            guard data.count <= Configuration.maximumResponseBytes else {
                #if DEBUG
                print("[LaunchLink] 响应过大（\(data.count) 字节），忽略。")
                #endif
                return nil
            }

            guard let candidate = Self.extractURLString(from: data) else { return nil }
            return Self.validate(candidate)
        } catch {
            #if DEBUG
            print("[LaunchLink] 请求失败：\(error.localizedDescription)")
            #endif
            return nil
        }
    }
}

// MARK: - 解析

extension LaunchLinkService {

    /// 只接受接口约定的成功响应：`code == 200` 且 `data.path` 非空。
    /// URL 协议与主机名由 `validate(_:)` 单独校验。
    static func extractURLString(from data: Data) -> String? {
        guard let response = try? JSONDecoder().decode(ResponseBody.self, from: data),
              response.code == 200 else {
            return nil
        }
        return clean(response.data.path)
    }

    private static func clean(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - 校验

extension LaunchLinkService {

    /// 把字符串变成一个可以安全交给 WKWebView 的 URL，否则 nil。
    ///
    /// 这是整个文件里最要紧的几行。WKWebView 会老实加载任何你给它的东西，
    /// 包括 `javascript:`（在页面上下文里执行脚本）、`data:`（把任意 HTML 当作
    /// 一个来源加载）、`file:`（读 app 沙盒里的文件）。这些都不能来自一个远程
    /// 返回的字符串，所以这里用白名单而不是黑名单：只有 https 能过。
    static func validate(_ candidate: String) -> URL? {
        guard var components = URLComponents(string: candidate) else { return nil }

        // 没写协议的当 https 补齐——"example.com/x" 这种后端很常见。
        // 注意此时 URLComponents 会把整串当 path，所以要重解一次。
        if components.scheme == nil {
            guard let rebuilt = URLComponents(string: "https://\(candidate)") else { return nil }
            components = rebuilt
        }

        guard let scheme = components.scheme?.lowercased(),
              Configuration.allowedSchemes.contains(scheme) else {
            #if DEBUG
            print("[LaunchLink] 协议不被允许：\(components.scheme ?? "nil")")
            #endif
            return nil
        }
        // 必须有主机名。https:/// 这种能构造出来但打不开。
        guard let host = components.host, !host.isEmpty else { return nil }

        return components.url
    }
}
