import XCTest
@testable import coufistgade

private struct StubLaunchLinkFetcher: LaunchLinkFetching {
    let url: URL?

    func fetchLink() async -> URL? {
        url
    }
}

@MainActor
final class SceneDelegateLaunchLinkTests: XCTestCase {

    private let link = URL(string: "https://promo.example.com/launch")!

    func testDirectEntryPresentsFetchedLinkExactlyOnce() async {
        let presented = expectation(description: "presents launch link")
        var presentationCount = 0
        let sut = makeSUT(url: link) { _, _, completion in
            presentationCount += 1
            completion(true)
            presented.fulfill()
        }
        let window = UIWindow()

        sut.start(in: window, skipsLaunchAnimation: true)

        await fulfillment(of: [presented], timeout: 1)
        XCTAssertTrue(window.rootViewController is UINavigationController)
        XCTAssertEqual(presentationCount, 1)

        sut.handleFetchedLaunchLink(link)
        XCTAssertEqual(presentationCount, 1)
    }

    func testLinkWaitsForLaunchHandoffBeforePresentation() async throws {
        let presented = expectation(description: "presents pending launch link")
        var presentationCount = 0
        let sut = makeSUT(url: nil) { _, _, completion in
            presentationCount += 1
            completion(true)
            presented.fulfill()
        }
        let window = UIWindow()
        sut.start(in: window, skipsLaunchAnimation: false)
        let launch = try XCTUnwrap(window.rootViewController as? LaunchViewController)

        sut.handleFetchedLaunchLink(link)
        XCTAssertEqual(presentationCount, 0)

        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(true) }
        launch.skip()

        await fulfillment(of: [presented], timeout: 1)
        XCTAssertTrue(window.rootViewController is UINavigationController)
        XCTAssertEqual(presentationCount, 1)
    }

    func testNilLinkDoesNotPresent() async {
        let notPresented = expectation(description: "does not present")
        notPresented.isInverted = true
        let sut = makeSUT(url: nil) { _, _, completion in
            completion(true)
            notPresented.fulfill()
        }

        sut.start(in: UIWindow(), skipsLaunchAnimation: true)

        await fulfillment(of: [notPresented], timeout: 0.1)
    }

    func testRejectedPresentationCanBeRetried() {
        var presentationCount = 0
        let sut = makeSUT(url: nil) { _, _, completion in
            presentationCount += 1
            completion(false)
        }
        sut.start(in: UIWindow(), skipsLaunchAnimation: true)

        sut.handleFetchedLaunchLink(link)
        sut.handleFetchedLaunchLink(link)

        XCTAssertEqual(presentationCount, 2)
    }

    func testAcceptedPresentationPreventsDuplicates() {
        var presentationCount = 0
        let sut = makeSUT(url: nil) { _, _, completion in
            presentationCount += 1
            completion(true)
        }
        sut.start(in: UIWindow(), skipsLaunchAnimation: true)

        sut.handleFetchedLaunchLink(link)
        sut.handleFetchedLaunchLink(link)

        XCTAssertEqual(presentationCount, 1)
    }

    private func makeSUT(
        url: URL?,
        presentationHandler: @escaping SceneDelegate.PresentationHandler
    ) -> SceneDelegate {
        SceneDelegate(
            launchLink: StubLaunchLinkFetcher(url: url),
            presentationHandler: presentationHandler
        )
    }
}
