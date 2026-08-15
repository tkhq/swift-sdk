import Foundation
import Testing
import TurnkeyCrypto

@testable import TurnkeyHttp

private final class RedirectURLProtocol: URLProtocol {
  static var requests: [URLRequest] = []
  static var response: ((URLRequest) -> (Int, String?))!
  private static let registration = URLProtocol.registerClass(RedirectURLProtocol.self)

  static func reset(response: @escaping (URLRequest) -> (Int, String?)) {
    _ = registration
    requests = []
    self.response = response
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    Self.requests.append(request)
    let (status, location) = Self.response(request)
    let headers = location.map { ["Location": $0] } ?? ["Content-Type": "application/json"]
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!

    if let location, let url = URL(string: location, relativeTo: request.url) {
      var redirect = request
      redirect.url = url.absoluteURL
      client?.urlProtocol(self, wasRedirectedTo: redirect, redirectResponse: response)
    }
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: location == nil ? Data("{\"ok\":true}".utf8) : Data())
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

@Suite(.serialized)
struct RedirectBehaviorTests {
  private func client(baseUrl: String) -> TurnkeyClient {
    let pair = TurnkeyCrypto.generateP256KeyPair()
    return TurnkeyClient(
      apiPrivateKey: pair.privateKey,
      apiPublicKey: pair.publicKeyCompressed,
      organizationId: "org-id",
      baseUrl: baseUrl
    )
  }

  @Test
  func stampedRequestStopsBeforeDowngradeInRedirectChain() async throws {
    RedirectURLProtocol.reset { request in
      switch request.url?.path {
      case "/start": (308, "/hop")
      case "/hop": (307, "http://api.example/final")
      default: (200, nil)
      }
    }

    do {
      let _: [String: Bool] = try await client(baseUrl: "https://api.example").request(
        "/start", body: [String: String]())
      Issue.record("expected redirect response")
    } catch TurnkeyRequestError.apiError(let status, _) {
      #expect(status == 307)
    }

    #expect(RedirectURLProtocol.requests.count == 2)
    #expect(RedirectURLProtocol.requests.allSatisfy { $0.url?.scheme == "https" })
    #expect(
      RedirectURLProtocol.requests.allSatisfy {
        $0.value(forHTTPHeaderField: "X-Stamp") != nil
      })
  }

  @Test
  func stampedRequestFollowsSameOriginDefaultPort() async throws {
    RedirectURLProtocol.reset { request in
      request.url?.path == "/start" ? (307, "https://api.example:443/final") : (200, nil)
    }

    let result: [String: Bool] = try await client(baseUrl: "https://api.example").request(
      "/start", body: [String: String]())

    #expect(result["ok"] == true)
    #expect(RedirectURLProtocol.requests.count == 2)
  }

  @Test
  func authProxyRequestStopsBeforePortChange() async throws {
    RedirectURLProtocol.reset { _ in (307, "https://proxy.example:8443/final") }
    let client = TurnkeyClient(
      authProxyConfigId: "config-id",
      organizationId: "org-id",
      authProxyUrl: "https://proxy.example"
    )

    do {
      let _: [String: Bool] = try await client.authProxyRequest(
        "/start", body: [String: String]())
      Issue.record("expected redirect response")
    } catch TurnkeyRequestError.apiError(let status, _) {
      #expect(status == 307)
    }

    #expect(RedirectURLProtocol.requests.count == 1)
    #expect(
      RedirectURLProtocol.requests[0].value(forHTTPHeaderField: "X-Auth-Proxy-Config-ID")
        == "config-id")
  }
}
