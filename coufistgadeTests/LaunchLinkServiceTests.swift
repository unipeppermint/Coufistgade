import Foundation
import XCTest

@testable import coufistgade

final class LaunchLinkServiceTests: XCTestCase {

    private final class MockURLProtocol: URLProtocol {
        static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    private let suiteName = "LaunchLinkServiceTests.\(UUID().uuidString)"
    private var defaults: UserDefaults!
    private var store: PersistenceManager!

    override func setUp() {
        super.setUp()
        guard let suiteDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test defaults suite")
            return
        }
        defaults = suiteDefaults
        defaults.removePersistentDomain(forName: suiteName)
        store = PersistenceManager(defaults: defaults)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchLinkUsesNetworkResponseAndCachesIt() async throws {
        let expected = URL(string: "https://example.com/path")!
        MockURLProtocol.requestHandler = { _ in
            let body = #"{"code":1,"data":{"path":"[https://example.com/path](https://example.com/path)","show":1,"useAF":0},"message":"request was successful"}"#.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: LaunchLinkService.Configuration.endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }

        let service = makeService()
        let actual = await service.fetchLink()

        XCTAssertEqual(actual, expected)
        XCTAssertEqual(store.launchLinkURLString, expected.absoluteString)
    }

    func testExtractURLStringUnwrapsMarkdownLink() {
        let data = #"{"code":1,"data":{"path":"[https://baidu.com](https://baidu.com)","show":1,"useAF":0},"message":"request was successful"}"#.data(using: .utf8)!
        let extracted = LaunchLinkService.extractURLString(from: data)

        XCTAssertEqual(extracted, "https://baidu.com")
    }

    func testFetchLinkFallsBackToCachedLinkWhenRequestFails() async throws {
        let cached = URL(string: "https://cached.example.com/launch")!
        store.saveLaunchLinkURL(cached)
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: LaunchLinkService.Configuration.endpoint,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let service = makeService()
        let actual = await service.fetchLink()

        XCTAssertEqual(actual, cached)
    }

    func testFetchLinkReturnsNilWithoutNetworkOrCache() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: LaunchLinkService.Configuration.endpoint,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let service = makeService()
        let actual = await service.fetchLink()

        XCTAssertNil(actual)
    }

    private func makeService() -> LaunchLinkService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 1
        configuration.timeoutIntervalForResource = 1
        let session = URLSession(configuration: configuration)
        return LaunchLinkService(session: session, store: store)
    }

}
