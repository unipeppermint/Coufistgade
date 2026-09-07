//
//  LaunchLinkFetchTests.swift
//  coufistgadeTests
//
//  `fetchLink()` 本身，用 URLProtocol 打桩，不碰真网络。
//
//  和 LaunchLinkServiceTests 分开：那个文件测的是两个纯函数（解析与校验），
//  这里测的是它们外面那层——状态码、体积上限、异常路径。这几条分支只有走一遍
//  URLSession 才碰得到，而它们恰好是「服务端出问题时 app 会怎样」的答案。
//
//  每一条的断言都是同一件事：**没拿到合法链接就返回 nil，绝不抛、绝不崩**。
//  启动路径上挂着这个请求，它必须永远失败得很安静。
//

import XCTest
@testable import coufistgade

/// 把响应钉在本地。
private final class StubURLProtocol: URLProtocol {

    /// 下一次请求要回的东西。测试串行跑，静态变量够用。
    nonisolated(unsafe) static var response: (status: Int, body: Data)?
    /// 设成非 nil 就模拟传输层失败（断网、超时）。
    nonisolated(unsafe) static var failure: Error?
    /// URLSession 实际交给协议层的请求，用来验证请求契约。
    nonisolated(unsafe) static var capturedRequest: URLRequest?
    nonisolated(unsafe) static var capturedBody: Data?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.capturedRequest = request
        Self.capturedBody = request.httpBody ?? Self.readBodyStream(request.httpBodyStream)
        Self.requestCount += 1

        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        guard let stub = Self.response, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBodyStream(_ stream: InputStream?) -> Data? {
        guard let stream else { return nil }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

final class LaunchLinkFetchTests: XCTestCase {

    private let endpoint = URL(string: "https://config.example.com/launch")!

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func makeService(username: String? = "com.example.test") -> LaunchLinkService {
        LaunchLinkService(
            endpoint: endpoint,
            username: username,
            session: makeSession()
        )
    }

    override func tearDown() {
        StubURLProtocol.response = nil
        StubURLProtocol.failure = nil
        StubURLProtocol.capturedRequest = nil
        StubURLProtocol.capturedBody = nil
        StubURLProtocol.requestCount = 0
        super.tearDown()
    }

    private func fetch(status: Int = 200, body: String) async -> URL? {
        StubURLProtocol.response = (status, Data(body.utf8))
        return await makeService().fetchLink()
    }

    // MARK: - 正常路径

    func testSuccessfulResponseReturnsDataPath() async {
        let link = await fetch(
            body: #"{"code":200,"data":{"path":"https://promo.example.com/x"}}"#
        )
        XCTAssertEqual(link?.absoluteString, "https://promo.example.com/x")
    }

    func testProductionRequestContract() async throws {
        StubURLProtocol.response = (200, Data(#"{}"#.utf8))
        let service = LaunchLinkService(
            session: makeSession()
        )

        _ = await service.fetchLink()

        let request = try XCTUnwrap(StubURLProtocol.capturedRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://pfhcdyh.top/v2/api/user/login")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(StubURLProtocol.capturedBody)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(object, ["username": "com.xkeso.baopvestor"])
    }

    func testUsernameIsEncodedAsJSON() async throws {
        StubURLProtocol.response = (200, Data(#"{}"#.utf8))
        let username = #"com.example."quoted\应用"#

        _ = await makeService(username: username).fetchLink()

        let body = try XCTUnwrap(StubURLProtocol.capturedBody)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: String]
        )
        XCTAssertEqual(object["username"], username)
    }

    func testMissingOrBlankUsernameSkipsRequest() async {
        for username in [nil, "", "   \n"] as [String?] {
            let link = await makeService(username: username).fetchLink()
            XCTAssertNil(link)
        }

        XCTAssertEqual(StubURLProtocol.requestCount, 0)
    }

    func testAnEmptyPayloadYieldsNil() async {
        // 「今天没有要开的页面」是这个接口最常见的正常回复。
        let link = await fetch(body: #"{}"#)
        XCTAssertNil(link)
    }

    // MARK: - 服务端出问题

    func testNon2xxIsIgnoredEvenWithAValidBody() async {
        // body 是合法的，但状态码说这次请求没成功。信状态码。
        for status in [301, 400, 401, 403, 404, 418, 500, 502, 503] {
            let link = await fetch(status: status, body: #"{"code":200,"data":{"path":"https://a.com"}}"#)
            XCTAssertNil(link, "HTTP \(status) 不该产出链接")
        }
    }

    func testBusinessFailureIsIgnoredEvenWithAValidPath() async {
        for code in [0, 201, 400, 500] {
            let link = await fetch(
                body: #"{"code":\#(code),"data":{"path":"https://a.com"}}"#
            )
            XCTAssertNil(link, "业务码 \(code) 不该产出链接")
        }
    }

    func testTransportFailureYieldsNil() async {
        // 断网、超时、DNS 挂掉。这是最要紧的一条：启动路径不能因为没网就卡住。
        for code in [URLError.notConnectedToInternet, .timedOut, .cannotFindHost, .networkConnectionLost] {
            StubURLProtocol.failure = URLError(code)
            let link = await makeService().fetchLink()
            XCTAssertNil(link, "\(code) 不该产出链接")
        }
    }

    func testAnOversizedBodyIsRejected() async {
        // 拿到的不是我们要的东西——正常响应是几十字节。构造一个超过上限的合法
        // JSON：真链接就在里面，仍然要拒，因为体积本身就是「这不对」的信号。
        let padding = String(repeating: "a", count: LaunchLinkService.Configuration.maximumResponseBytes)
        let link = await fetch(body: #"{"code":200,"pad":"\#(padding)","data":{"path":"https://a.com"}}"#)
        XCTAssertNil(link)
    }

    func testABodyJustUnderTheCapStillWorks() async {
        // 上限的另一边：证明拒绝的是体积，不是「带了别的字段」。
        let padding = String(repeating: "a", count: 1_000)
        let link = await fetch(body: #"{"code":200,"pad":"\#(padding)","data":{"path":"https://a.com"}}"#)
        XCTAssertEqual(link?.absoluteString, "https://a.com")
    }

    func testMalformedJSONYieldsNil() async {
        let link = await fetch(body: #"{"code":200,"data":{"path":"https://a.com"}"#)  // 少个括号
        XCTAssertNil(link)
    }

    // MARK: - 恶意响应

    func testAHostileSchemeFromTheServerNeverEscapes() async {
        // 端到端版本的白名单检查：即便服务端被拿下并回了这些，fetchLink 也不该
        // 交出一个能塞进 WKWebView 的 URL。
        let hostile = [
            "javascript:alert(document.cookie)",
            "data:text/html,<script>fetch('https://evil.com')</script>",
            "file:///etc/passwd",
            "http://insecure.example.com",
        ]
        for candidate in hostile {
            let body = try! String(
                data: JSONSerialization.data(withJSONObject: ["code": 200, "data": ["path": candidate]]),
                encoding: .utf8
            )!
            let link = await fetch(body: body)
            XCTAssertNil(link, "\(candidate) 不该从 fetchLink 出来")
        }
    }
}
