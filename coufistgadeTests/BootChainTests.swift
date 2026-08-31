//
//  BootChainTests.swift
//  coufistgadeTests
//
//  Phase 1 guards: the app boots programmatically and ships no Interface Builder files.
//

import XCTest
@testable import coufistgade

final class BootChainTests: XCTestCase {

    func testHomeViewControllerLoadsViewWithoutNib() {
        let sut = HomeViewController()

        XCTAssertNil(sut.nibName, "Home must not be backed by a nib or storyboard.")

        sut.loadViewIfNeeded()

        XCTAssertNotNil(sut.viewIfLoaded, "Home should build its view programmatically.")
    }

    func testHomeViewControllerUsesAppBackground() {
        let sut = HomeViewController()
        sut.loadViewIfNeeded()

        XCTAssertEqual(sut.view.backgroundColor, UIColor(resource: .appBackground))
    }

    func testBundleContainsNoCompiledInterfaceBuilderFiles() {
        let bundle = Bundle(for: AppDelegate.self)

        XCTAssertNil(bundle.path(forResource: "Main", ofType: "storyboardc"))
        XCTAssertNil(bundle.path(forResource: "LaunchScreen", ofType: "storyboardc"))
    }

    func testSceneManifestDeclaresSceneDelegateAndNoStoryboard() throws {
        let bundle = Bundle(for: AppDelegate.self)
        let manifest = try XCTUnwrap(
            bundle.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any]
        )
        let configurations = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        let sessionRole = try XCTUnwrap(
            configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]]
        )
        let configuration = try XCTUnwrap(sessionRole.first)

        XCTAssertEqual(configuration["UISceneDelegateClassName"] as? String, "coufistgade.SceneDelegate")
        XCTAssertNil(configuration["UISceneStoryboardFile"], "Scene must not be storyboard-driven.")
        XCTAssertNil(bundle.object(forInfoDictionaryKey: "UIMainStoryboardFile"))
    }
}
