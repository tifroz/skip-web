// Copyright 2024–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if os(iOS) && !SKIP
import XCTest
@testable import SkipWeb

final class WebEngineNavigationDelegateTests: XCTestCase {
    @MainActor
    private final class RecordingNavigationDelegate: SkipWebNavigationDelegate {
        var requestedURLs: [URL] = []
        var events: [String] = []

        func webEngine(_ engine: WebEngine, shouldOverrideURLLoading url: URL) -> Bool {
            requestedURLs.append(url)
            return false
        }

        func webEngineDidStartProvisionalNavigation(_ engine: WebEngine) {
            events.append("started")
        }

        func webEngineDidCommitNavigation(_ engine: WebEngine) {
            events.append("committed")
        }

        func webEngineDidFinishNavigation(_ engine: WebEngine) {
            events.append("finished")
        }

        func webEngine(_ engine: WebEngine, didFailNavigation error: Error) {
            events.append("failed")
        }
    }

    @MainActor
    func testLoadForwardsNavigationCallbacksToConfigurationDelegate() async throws {
        let delegate = RecordingNavigationDelegate()
        let configuration = WebEngineConfiguration(navigationDelegate: delegate)
        let engine = WebEngine(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "about:blank"))

        try await engine.load(url: url)

        XCTAssertEqual(delegate.requestedURLs, [url])
        XCTAssertEqual(delegate.events, ["started", "committed", "finished"])
    }
}
#endif
