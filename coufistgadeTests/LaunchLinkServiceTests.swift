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

    func testSuccessfulResponseReturnsDataPath() {
        XCTAssertEqual(
            extract(#"{"code":200,"data":{"path":"https://a.com"}}"#),
            "https://a.com"
        )
    }

    func testPathWhitespaceIsTrimmed() {
        XCTAssertEqual(
            extract(#"{"code":200,"data":{"path":"  https://a.com  "}}"#),
            "https://a.com"
        )
    }

    func testBusinessCodeMustBe200() {
        XCTAssertNil(extract(#"{"code":0,"data":{"path":"https://a.com"}}"#))
        XCTAssertNil(extract(#"{"code":500,"data":{"path":"https://a.com"}}"#))
    }

    func testMissingOrInvalidDataPathYieldsNil() {
        XCTAssertNil(extract(#"{}"#))
        XCTAssertNil(extract(#"{"code":200}"#))
        XCTAssertNil(extract(#"{"code":200,"data":{}}"#))
        XCTAssertNil(extract(#"{"code":200,"data":{"path":""}}"#))
        XCTAssertNil(extract(#"{"code":200,"data":{"path":42}}"#))
        XCTAssertNil(extract(#"{"code":"200","data":{"path":"https://a.com"}}"#))
    }

    func testLegacyResponseShapesAreRejected() {
        XCTAssertNil(extract(#"{"path":"https://a.com"}"#))
        XCTAssertNil(extract(#"{"url":"https://a.com"}"#))
        XCTAssertNil(extract(#""https://a.com""#))
        XCTAssertNil(extract("https://a.com"))
    }

    func testParsingDoesNotValidateScheme() {
        XCTAssertEqual(
            extract(#"{"code":200,"data":{"path":"javascript:alert(1)"}}"#),
            "javascript:alert(1)"
        )
        XCTAssertNil(LaunchLinkService.validate("javascript:alert(1)"))
    }
}
