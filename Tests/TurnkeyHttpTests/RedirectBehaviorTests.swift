import Foundation
import Testing
import TurnkeyCrypto

@testable import TurnkeyHttp

private struct EmptyBody: Codable {}

private struct OkResponse: Codable {
  let ok: Bool
}

final class RecordingURLProtocol: URLProtocol {
  static var handler: ((URLRequest) -> (Int, [String: String], Data))?
  static var recorded: [(request: URLRequest, body: Data?)] = []

  static func reset(handler: @escaping (URLRequest) -> (Int, [String: String], Data)) {
    _ = registration
    recorded = []
    self.handler = handler
  }

  private static let registration: Bool = URLProtocol.registerClass(RecordingURLProtocol.self)

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    let body = Self.drainBody(of: request)
    Self.recorded.append((request, body))

    guard let handler = Self.handler, let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }

    let (status, headers, data) = handler(request)
    let response = HTTPURLResponse(
      url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!

    if (300...399).contains(status), let location = headers["Location"],
      let redirectUrl = URL(string: location, relativeTo: url)
    {
      var redirected = request
      redirected.url = redirectUrl.absoluteURL
      redirected.httpBodyStream = nil
      redirected.httpBody = body
      client?.urlProtocol(self, wasRedirectedTo: redirected, redirectResponse: response)
    }

    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  private static func drainBody(of request: URLRequest) -> Data? {
    if let body = request.httpBody {
      return body
    }
    guard let stream = request.httpBodyStream else {
      return nil
    }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
      let count = stream.read(buffer, maxLength: bufferSize)
      if count <= 0 {
        break
      }
      data.append(buffer, count: count)
    }
    return data
  }
}

@Suite(.serialized)
struct RedirectBehaviorTests {

  private func makeStampedClient(baseUrl: String) -> TurnkeyClient {
    let pair = TurnkeyCrypto.generateP256KeyPair()
    return TurnkeyClient(
      apiPrivateKey: pair.privateKey,
      apiPublicKey: pair.publicKeyCompressed,
      organizationId: "org-id",
      baseUrl: baseUrl
    )
  }

  private func okBody() -> Data {
    Data("{\"ok\":true}".utf8)
  }

  @Test
  func originComparison() throws {
    func url(_ string: String) -> URL {
      URL(string: string)!
    }
    #expect(
      SameOriginRedirectDelegate.hasSameOrigin(
        url("https://a.example/x"), url("https://a.example:443/y")))
    #expect(
      SameOriginRedirectDelegate.hasSameOrigin(
        url("http://a.example:80/x"), url("http://a.example/y")))
    #expect(
      SameOriginRedirectDelegate.hasSameOrigin(
        url("HTTPS://A.EXAMPLE/x"), url("https://a.example/y")))
    #expect(
      !SameOriginRedirectDelegate.hasSameOrigin(
        url("https://a.example/x"), url("http://a.example/y")))
    #expect(
      !SameOriginRedirectDelegate.hasSameOrigin(
        url("https://a.example/x"), url("https://b.example/y")))
    #expect(
      !SameOriginRedirectDelegate.hasSameOrigin(
        url("https://a.example/x"), url("https://a.example:8443/y")))
    #expect(
      !SameOriginRedirectDelegate.hasSameOrigin(
        url("https://a.example/x"), url("https://sub.a.example/y")))
  }

  @Test
  func crossOriginRedirectIsNotFollowed() async throws {
    RecordingURLProtocol.reset { request in
      if request.url?.host == "origin-a.example" {
        return (307, ["Location": "https://elsewhere.example/next"], Data())
      }
      return (200, ["Content-Type": "application/json"], self.okBody())
    }

    let client = makeStampedClient(baseUrl: "https://origin-a.example")
    do {
      let _: OkResponse = try await client.request("/v1/thing", body: EmptyBody())
      Issue.record("expected the request to fail")
    } catch TurnkeyRequestError.apiError(let statusCode, _) {
      #expect(statusCode == 307)
    }

    #expect(RecordingURLProtocol.recorded.count == 1)
    let initial = RecordingURLProtocol.recorded[0]
    #expect(initial.request.value(forHTTPHeaderField: "X-Stamp") != nil)
    #expect((initial.body ?? Data()).isEmpty == false)
  }

  @Test
  func sameOriginRedirectIsFollowed() async throws {
    RecordingURLProtocol.reset { request in
      if request.url?.path == "/v1/thing" {
        return (307, ["Location": "https://origin-b.example:443/v1/final"], Data())
      }
      return (200, ["Content-Type": "application/json"], self.okBody())
    }

    let client = makeStampedClient(baseUrl: "https://origin-b.example")
    let response: OkResponse = try await client.request("/v1/thing", body: EmptyBody())
    #expect(response.ok)

    #expect(RecordingURLProtocol.recorded.count == 2)
    let initial = RecordingURLProtocol.recorded[0]
    let followUp = RecordingURLProtocol.recorded[1]
    #expect(followUp.request.url?.path == "/v1/final")
    let stamp = initial.request.value(forHTTPHeaderField: "X-Stamp")
    #expect(stamp != nil)
    #expect(followUp.request.value(forHTTPHeaderField: "X-Stamp") == stamp)
    #expect(followUp.body == initial.body)
  }

  @Test
  func redirectChainStopsAtForeignOrigin() async throws {
    RecordingURLProtocol.reset { request in
      switch request.url?.path {
      case "/v1/thing":
        return (308, ["Location": "/v1/hop"], Data())
      case "/v1/hop":
        return (307, ["Location": "https://elsewhere.example/v1/final"], Data())
      default:
        return (200, ["Content-Type": "application/json"], self.okBody())
      }
    }

    let client = makeStampedClient(baseUrl: "https://origin-c.example")
    do {
      let _: OkResponse = try await client.request("/v1/thing", body: EmptyBody())
      Issue.record("expected the request to fail")
    } catch TurnkeyRequestError.apiError(let statusCode, _) {
      #expect(statusCode == 307)
    }

    #expect(RecordingURLProtocol.recorded.count == 2)
    #expect(RecordingURLProtocol.recorded[1].request.url?.host == "origin-c.example")
  }

  @Test
  func authProxyCrossOriginRedirectIsNotFollowed() async throws {
    RecordingURLProtocol.reset { request in
      if request.url?.host == "origin-d.example" {
        return (307, ["Location": "https://elsewhere.example/next"], Data())
      }
      return (200, ["Content-Type": "application/json"], self.okBody())
    }

    let client = TurnkeyClient(
      authProxyConfigId: "config-id",
      organizationId: "org-id",
      authProxyUrl: "https://origin-d.example"
    )
    do {
      let _: OkResponse = try await client.authProxyRequest("/v1/thing", body: EmptyBody())
      Issue.record("expected the request to fail")
    } catch TurnkeyRequestError.apiError(let statusCode, _) {
      #expect(statusCode == 307)
    }

    #expect(RecordingURLProtocol.recorded.count == 1)
    let initial = RecordingURLProtocol.recorded[0]
    #expect(initial.request.value(forHTTPHeaderField: "X-Auth-Proxy-Config-ID") == "config-id")
  }
}
