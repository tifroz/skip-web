// Copyright 2024–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if os(iOS) && !SKIP
import SwiftUI
import UIKit
import WebKit
import XCTest
@testable import SkipWeb

final class WebViewLifecycleTests: XCTestCase {
    @MainActor
    func testNavigatorOwnedEngineIsMountedWithoutCreatingAReplacement() {
        let navigator = WebViewNavigator()
        let ownedEngine = WebEngine(configuration: WebEngineConfiguration())
        navigator.webEngine = ownedEngine

        withMountedWebView(SkipWeb.WebView(navigator: navigator)) { mountedWebView in
            XCTAssertTrue(mountedWebView === ownedEngine.webView)
            XCTAssertTrue(navigator.webEngine === ownedEngine)
        }
    }

    @MainActor
    func testUnderlyingWebViewIsReleasedAfterSwiftUIHostIsReleased() {
        let retainedWebView = mountAndRelease(SkipWeb.WebView())

        drainMainRunLoop()
        XCTAssertNil(retainedWebView.value)
    }

    @MainActor
    func testPersistentWebViewIsReleasedAfterCacheEviction() {
        let persistentWebViewID = "lifecycle-\(UUID().uuidString)"
        let retainedWebView = mountAndRelease(SkipWeb.WebView(persistentWebViewID: persistentWebViewID))
        let retainedEngine = WeakReference<WebEngine>()
        retainedEngine.value = SkipWeb.WebView.cachedPersistentWebEngine(id: persistentWebViewID)

        drainMainRunLoop()
        XCTAssertNotNil(retainedWebView.value)
        XCTAssertNotNil(retainedEngine.value)

        SkipWeb.WebView.removePersistentWebView(id: persistentWebViewID)
        drainMainRunLoop()
        XCTAssertNil(SkipWeb.WebView.cachedPersistentWebEngine(id: persistentWebViewID))
        XCTAssertNil(retainedEngine.value)
        XCTAssertNil(retainedWebView.value)
    }

    @MainActor
    private func mountAndRelease(_ webView: SkipWeb.WebView) -> WeakReference<WKWebView> {
        let retainedWebView = WeakReference<WKWebView>()

        autoreleasepool {
            let host = UIHostingController(rootView: webView)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()

            retainedWebView.value = findWebView(in: host.view)
            XCTAssertNotNil(retainedWebView.value)

            window.rootViewController = nil
            window.isHidden = true
        }

        return retainedWebView
    }

    @MainActor
    private func withMountedWebView(
        _ webView: SkipWeb.WebView,
        assertions: (WKWebView) -> Void
    ) {
        autoreleasepool {
            let host = UIHostingController(rootView: webView)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()

            guard let mountedWebView = findWebView(in: host.view) else {
                XCTFail("Expected a mounted WKWebView")
                return
            }
            assertions(mountedWebView)

            window.rootViewController = nil
            window.isHidden = true
        }
    }

    @MainActor
    private func findWebView(in view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        for subview in view.subviews {
            if let webView = findWebView(in: subview) {
                return webView
            }
        }
        return nil
    }

    @MainActor
    private func drainMainRunLoop(iterations: Int = 5) {
        for _ in 0..<iterations {
            autoreleasepool {
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
        }
    }
}

private final class WeakReference<Value: AnyObject> {
    weak var value: Value?
}
#endif
