//
//  LaunchLinkServiceTests.swift
//  coufistgadeTests
//
//  重点在两件事上：**协议白名单**与**响应解析**。
//
//  白名单是这个功能里唯一真正危险的地方——那个字符串来自网络，而 WKWebView 会
//  老实加载任何东西，包括 javascript:（在页面上下文里执行脚本）、data:（把任意
//  HTML 当作一个来源）、file:（读 app 沙盒）。所以这里逐个 scheme 钉死。
//
//  解析走的是纯函数（`extractURLString` / `validate`），不碰网络，所以这些用例
//  不需要 URLProtocol 打桩就能覆盖全部形状。
//

import XCTest
@testable import coufistgade

final class LaunchLinkServiceTests: XCTestCase {

    // MARK: - 协议白名单

    func testHTTPSPasses() {
        XCTAssertEqual(
            LaunchLinkService.validate("https://example.com/promo")?.absoluteString,
            "https://example.com/promo"
        )
    }

    func testSchemelessStringIsPromotedToHTTPS() {
        // 后端常常只回 "example.com/x"。补 https 而不是拒掉，但补的必须是 https。
        XCTAssertEqual(
            LaunchLinkService.validate("example.com/x")?.absoluteString,
            "https://example.com/x"
        )
    }

    func testEveryDangerousSchemeIsRejected() {
        // 这条用例是这个文件存在的理由。任何一条漏过去都意味着远程字符串可以在
        // WKWebView 里执行脚本、伪造来源、或读本地文件。
        let hostile = [
            "javascript:alert(document.cookie)",
            "JavaScript:alert(1)",              // 大小写绕过
            "data:text/html;base64,PHNjcmlwdD4=",
            "file:///etc/passwd",
            "file://localhost/Applications",
            "about:blank",
            "ftp://example.com/x",
            "itms-apps://apps.apple.com/app/id1",
            "tel:+10000000000",
            "mailto:a@b.c",
        ]
        for candidate in hostile {
            XCTAssertNil(
                LaunchLinkService.validate(candidate),
                "\(candidate) 不该通过校验"
            )
        }
    }

    func testPlainHTTPIsRejected() {
        // ATS 也会拦，但那是加载那一刻的事。在这里就拒掉，明确得多。
        XCTAssertNil(LaunchLinkService.validate("http://example.com"))
    }

    func testURLWithoutHostIsRejected() {
        // 这几个能构造成 URL，但打不开。
        XCTAssertNil(LaunchLinkService.validate("https://"))
        XCTAssertNil(LaunchLinkService.validate("https:///path"))
    }

    func testGarbageIsRejected() {
        XCTAssertNil(LaunchLinkService.validate(""))
        XCTAssertNil(LaunchLinkService.validate("   "))
    }

    func testQueryAndFragmentSurvive() {
        // 这类页面常带渠道参数，丢掉的话统计就断了。
        let url = LaunchLinkService.validate("https://e.com/p?utm=push&id=7#top")
        XCTAssertEqual(url?.query, "utm=push&id=7")
        XCTAssertEqual(url?.fragment, "top")
    }
}

// MARK: - 响应解析

extension LaunchLinkServiceTests {

    private func extract(_ json: String) -> String? {
        LaunchLinkService.extractURLString(from: Data(json.utf8))
    }

    func testTopLevelURLKey() {
        XCTAssertEqual(extract(#"{"url": "https://a.com"}"#), "https://a.com")
    }

    func testAlternateKeyNames() {
        // 字段名常常是后端顺手定的，而客户端改一次要发一个版本。
        XCTAssertEqual(extract(#"{"link": "https://a.com"}"#), "https://a.com")
        XCTAssertEqual(extract(#"{"redirect": "https://a.com"}"#), "https://a.com")
        XCTAssertEqual(extract(#"{"webUrl": "https://a.com"}"#), "https://a.com")
        XCTAssertEqual(extract(#"{"web_url": "https://a.com"}"#), "https://a.com")
        XCTAssertEqual(extract(#"{"h5Url": "https://a.com"}"#), "https://a.com")
    }

    func testWrappedInDataObject() {
        // { code, msg, data: { url } } 是最常见的包法。
        XCTAssertEqual(
            extract(#"{"code": 0, "msg": "ok", "data": {"url": "https://a.com"}}"#),
            "https://a.com"
        )
    }

    func testDataIsItselfAString() {
        XCTAssertEqual(extract(#"{"code": 0, "data": "https://a.com"}"#), "https://a.com")
    }

    func testBareJSONString() {
        XCTAssertEqual(extract(#""https://a.com""#), "https://a.com")
    }

    func testPlainTextBody() {
        // 接口直接回一行地址，不是 JSON。
        XCTAssertEqual(extract("https://a.com\n"), "https://a.com")
    }

    func testWhitespaceIsTrimmed() {
        XCTAssertEqual(extract(#"{"url": "  https://a.com  "}"#), "https://a.com")
    }

    func testEmptyAndAbsentValuesYieldNil() {
        // 「没有链接」是这个接口最常见的正常回复，必须干净地返回 nil。
        XCTAssertNil(extract(#"{}"#))
        XCTAssertNil(extract(#"{"url": ""}"#))
        XCTAssertNil(extract(#"{"url": "   "}"#))
        XCTAssertNil(extract(#"{"code": 0, "data": {}}"#))
        XCTAssertNil(extract(#"{"url": null}"#))
        XCTAssertNil(extract(""))
    }

    func testWrongTypesYieldNil() {
        // 后端把 url 写成了数字或数组，不该崩也不该乱猜。
        XCTAssertNil(extract(#"{"url": 42}"#))
        XCTAssertNil(extract(#"{"url": ["https://a.com"]}"#))
        XCTAssertNil(extract(#"{"url": {"href": "https://a.com"}}"#))
    }

    func testKeyPriorityIsStable() {
        // 同时给了 url 和 link 时取 url，和 urlKeys 的顺序一致。
        XCTAssertEqual(
            extract(#"{"link": "https://b.com", "url": "https://a.com"}"#),
            "https://a.com"
        )
    }

    func testParsingDoesNotValidate() {
        // 解析层故意不做协议判断——它只负责挖出字符串，白名单由 validate 执行。
        // 分开是为了让「挖得出来」和「可以打开」各自可测。
        XCTAssertEqual(
            extract(#"{"url": "javascript:alert(1)"}"#),
            "javascript:alert(1)"
        )
        XCTAssertNil(LaunchLinkService.validate("javascript:alert(1)"))
    }
}

// MARK: - 端点缺失

extension LaunchLinkServiceTests {

    func testNoEndpointMeansNoRequest() async {
        // Info.plist 里 LaunchLinkEndpoint 是空串，等于功能关闭。这条用例证明
        // 默认构造不会发请求、也不会返回链接——新克隆的仓库跑起来就是这个状态。
        let service = LaunchLinkService()
        let link = await service.fetchLink()
        XCTAssertNil(link)
    }
}
