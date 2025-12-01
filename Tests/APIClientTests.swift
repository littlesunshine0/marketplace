import Foundation
import XCTest

final class APIClientTests: XCTestCase {
    private let baseURL = URL(string: "https://example.com")!

    func testRequestDecodesResponseAndAddsAuthorizationHeader() async throws {
        let authManager = MockAuthenticationManager(initialToken: "test-token")
        let session = makeMockSession()
        let client = APIClient(baseURL: baseURL, authenticationManager: authManager, session: session)

        let expected = TestResponse(value: "ok")
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONEncoder().encode(expected)
            return (response, data)
        }

        let result: TestResponse = try await client.request(TestEndpoint(), expecting: TestResponse.self)
        XCTAssertEqual(result, expected)
    }

    func testUnauthorizedResponseTriggersTokenRefreshAndRetries() async throws {
        let authManager = MockAuthenticationManager(initialToken: "expired-token")
        let session = makeMockSession()
        let client = APIClient(baseURL: baseURL, authenticationManager: authManager, session: session)

        var responses: [(code: Int, body: Data)] = [
            (401, Data("{}".utf8)),
            (200, try JSONEncoder().encode(TestResponse(value: "ok")))
        ]
        var observedAuthorizationHeaders: [String?] = []

        MockURLProtocol.requestHandler = { request in
            observedAuthorizationHeaders.append(request.value(forHTTPHeaderField: "Authorization"))
            let next = responses.removeFirst()
            let response = HTTPURLResponse(url: request.url!, statusCode: next.code, httpVersion: nil, headerFields: nil)!
            return (response, next.body)
        }

        let result: TestResponse = try await client.request(TestEndpoint(), expecting: TestResponse.self)

        XCTAssertEqual(result, TestResponse(value: "ok"))
        XCTAssertEqual(await authManager.refreshCount, 1)
        XCTAssertEqual(observedAuthorizationHeaders.first??.replacingOccurrences(of: "Bearer ", with: ""), "expired-token")
        XCTAssertEqual(observedAuthorizationHeaders.last??.replacingOccurrences(of: "Bearer ", with: ""), "refreshed-token-1")
    }

    // MARK: - Helpers

    private func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private struct TestResponse: Codable, Equatable {
    let value: String
}

private struct TestEndpoint: APIEndpoint {
    let platform: MarketplacePlatform = .ebay
    let path: String = "/test"
    let method: String = "GET"
    let headers: [String: String] = [:]
    let body: Data? = nil
}

// MARK: - Test Doubles

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
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

actor MockAuthenticationManager: AuthenticationManaging {
    private var token: String?
    private(set) var refreshCount: Int = 0

    init(initialToken: String?) {
        self.token = initialToken
    }

    func validAccessToken(for platform: MarketplacePlatform) async throws -> String? {
        token
    }

    func refreshToken(for platform: MarketplacePlatform) async throws {
        refreshCount += 1
        token = "refreshed-token-\(refreshCount)"
    }
}
