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
//  3. **不配置就等于关闭。** 端点读 Info.plist 的 LaunchLinkEndpoint，缺了就
//     直接返回 nil，和 PushNotificationService 缺 plist 时的处理方式一致。
//
//  不碰 Firebase：这是一次普通的 HTTPS GET，用 URLSession 就够，没有理由为它
//  引入 Remote Config。
//

import Foundation

/// 启动链接的来源。抽成协议只为了测试能塞一个假的进来，生产只有一个实现。
protocol LaunchLinkFetching: Sendable {
    func fetchLink() async -> URL?
}

final class LaunchLinkService: LaunchLinkFetching {

    enum Configuration {
        /// Info.plist 里放端点的键。没有这个键就等于功能关闭。
        static let endpointKey = "LaunchLinkEndpoint"

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

    private let session: URLSession
    private let endpoint: URL?

    /// - Parameters:
    ///   - endpoint: 覆盖 Info.plist 里的端点，测试用。
    ///   - session: 覆盖默认 session，测试用。
    init(endpoint: URL? = nil, session: URLSession? = nil) {
        self.endpoint = endpoint ?? Self.endpointFromBundle()

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

    private static func endpointFromBundle() -> URL? {
        guard let raw = Bundle.main.object(
            forInfoDictionaryKey: Configuration.endpointKey
        ) as? String else { return nil }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}

// MARK: - 取链接

extension LaunchLinkService {

    /// 问一次服务端。没有链接、或任何一步出错，都返回 nil。
    ///
    /// 不 throw：调用方对「为什么没有」无能为力，能做的只有照常启动。错误只在
    /// DEBUG 下打日志。
    func fetchLink() async -> URL? {
        guard let endpoint else {
            #if DEBUG
            print("""
                [LaunchLink] Info.plist 里没有 \(Configuration.endpointKey)，已跳过。
                要启用就加一条这个键，值为 https 的接口地址。
                """)
            #endif
            return nil
        }

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = Configuration.timeout
            request.setValue("application/json", forHTTPHeaderField: "Accept")

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

    /// 响应里可能放链接的字段名，按优先级。
    ///
    /// 认多个键而不是钉死一个，是因为这类接口的字段名常常是后端顺手定的，
    /// 而客户端改一次要发一个版本。顶层和 data 里各找一遍。
    private static let urlKeys = ["url", "link", "redirect", "webUrl", "web_url", "h5Url"]

    /// 从响应体里挖出那个字符串。
    ///
    /// 接受三种形状：裸字符串、`{"url": "..."}`、`{"data": {"url": "..."}}`。
    static func extractURLString(from data: Data) -> String? {
        // 先当 JSON 解。
        //
        // `.fragmentsAllowed` 是必须的：不给这个选项时 JSONSerialization 只接受
        // 顶层是对象或数组的输入，接口回一个裸字符串（`"https://a.com"`，合法
        // JSON）会被判为失败，掉到下面的纯文本分支，于是引号被当成地址的一部分。
        if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            if let string = object as? String { return clean(string) }

            if let dictionary = object as? [String: Any] {
                if let found = firstURLString(in: dictionary) { return found }
                // 常见的 { code, msg, data: { url } } 包一层。
                if let nested = dictionary["data"] as? [String: Any],
                   let found = firstURLString(in: nested) {
                    return found
                }
                // data 直接就是字符串的情形。
                if let string = dictionary["data"] as? String { return clean(string) }
            }
            return nil
        }

        // 不是 JSON：当纯文本，接口直接回一行地址的情况。
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return clean(text)
    }

    private static func firstURLString(in dictionary: [String: Any]) -> String? {
        for key in urlKeys {
            if let string = dictionary[key] as? String, let cleaned = clean(string) {
                return cleaned
            }
        }
        return nil
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
