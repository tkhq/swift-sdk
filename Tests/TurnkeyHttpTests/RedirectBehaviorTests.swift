import Foundation
import Testing
import TurnkeyCrypto

@testable import TurnkeyHttp

private struct RecordedRequest {
  let method: String
  let path: String
  let headers: [String: String]
  let body: Data
}

private final class LoopbackHTTPServer: @unchecked Sendable {
  private let listenFD: Int32
  private let lock = NSLock()
  private var recorded: [RecordedRequest] = []
  private let respond: @Sendable (String) -> (Int, String?)
  let port: Int

  var requests: [RecordedRequest] {
    lock.lock()
    defer { lock.unlock() }
    return recorded
  }

  init(respond: @escaping @Sendable (String) -> (Int, String?)) {
    self.respond = respond
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
    let bound = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    precondition(bound == 0 && listen(fd, 16) == 0)
    var boundAddress = sockaddr_in()
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    _ = withUnsafeMutablePointer(to: &boundAddress) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        getsockname(fd, $0, &length)
      }
    }
    listenFD = fd
    port = Int(UInt16(bigEndian: boundAddress.sin_port))
    Thread.detachNewThread { [self] in
      while true {
        let connection = accept(listenFD, nil, nil)
        if connection < 0 { return }
        handle(connection)
      }
    }
  }

  var baseUrl: String { "http://127.0.0.1:\(port)" }

  func stop() {
    close(listenFD)
  }

  private func handle(_ fd: Int32) {
    defer { close(fd) }
    var buffer = Data()
    var chunk = [UInt8](repeating: 0, count: 4096)
    let separator = Data("\r\n\r\n".utf8)
    var headerEnd = buffer.range(of: separator)
    while headerEnd == nil {
      let count = read(fd, &chunk, chunk.count)
      if count <= 0 { return }
      buffer.append(contentsOf: chunk[0..<count])
      headerEnd = buffer.range(of: separator)
    }
    guard let headerEnd else { return }
    let head = String(decoding: buffer[..<headerEnd.lowerBound], as: UTF8.self)
    var lines = head.components(separatedBy: "\r\n")
    let requestLine = lines.removeFirst().components(separatedBy: " ")
    guard requestLine.count >= 2 else { return }
    var headers: [String: String] = [:]
    for line in lines {
      guard let colon = line.firstIndex(of: ":") else { continue }
      headers[line[..<colon].lowercased()] =
        line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
    }
    let contentLength = headers["content-length"].flatMap(Int.init) ?? 0
    var body = Data(buffer[headerEnd.upperBound...])
    while body.count < contentLength {
      let count = read(fd, &chunk, chunk.count)
      if count <= 0 { break }
      body.append(contentsOf: chunk[0..<count])
    }
    lock.lock()
    recorded.append(
      RecordedRequest(method: requestLine[0], path: requestLine[1], headers: headers, body: body))
    lock.unlock()
    let (status, location) = respond(requestLine[1])
    let payload = location == nil ? Data("{\"ok\":true}".utf8) : Data()
    var response = "HTTP/1.1 \(status) Status\r\nContent-Length: \(payload.count)\r\n"
    response += "Connection: close\r\n"
    if let location {
      response += "Location: \(location)\r\n"
    } else {
      response += "Content-Type: application/json\r\n"
    }
    response += "\r\n"
    var out = Data(response.utf8)
    out.append(payload)
    out.withUnsafeBytes { _ = write(fd, $0.baseAddress, $0.count) }
  }
}

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
  func stampedRequestFollowsSameOrigin307And308PreservingRequest() async throws {
    let server = LoopbackHTTPServer { path in
      switch path {
      case "/start": (308, "/hop")
      case "/hop": (307, "/final")
      default: (200, nil)
      }
    }
    defer { server.stop() }

    let result: [String: Bool] = try await client(baseUrl: server.baseUrl).request(
      "/start", body: [String: String]())

    #expect(result["ok"] == true)
    let requests = server.requests
    #expect(requests.map(\.path) == ["/start", "/hop", "/final"])
    #expect(requests.allSatisfy { $0.method == "POST" })
    #expect(!requests[0].body.isEmpty)
    #expect(Set(requests.map(\.body)).count == 1)
    #expect(requests.allSatisfy { $0.headers["x-stamp"] != nil })
  }

  @Test(arguments: [300, 301, 302, 303])
  func stampedRequestRefusesNonPreservingRedirect(status: Int) async throws {
    let server = LoopbackHTTPServer { _ in (status, "/elsewhere") }
    defer { server.stop() }

    do {
      let _: [String: Bool] = try await client(baseUrl: server.baseUrl).request(
        "/start", body: [String: String]())
      Issue.record("expected redirect refusal")
    } catch let error as TurnkeyRequestError {
      #expect(error == .redirectRefused(statusCode: status, location: "/elsewhere"))
    }

    #expect(server.requests.count == 1)
  }

  @Test
  func stampedRequestRefusesCrossOriginRedirectMidChain() async throws {
    let other = LoopbackHTTPServer { _ in (200, nil) }
    defer { other.stop() }
    let crossOriginTarget = "\(other.baseUrl)/final"
    let server = LoopbackHTTPServer { path in
      path == "/start" ? (308, "/hop") : (307, crossOriginTarget)
    }
    defer { server.stop() }

    do {
      let _: [String: Bool] = try await client(baseUrl: server.baseUrl).request(
        "/start", body: [String: String]())
      Issue.record("expected redirect refusal")
    } catch let error as TurnkeyRequestError {
      #expect(error == .redirectRefused(statusCode: 307, location: crossOriginTarget))
    }

    #expect(server.requests.map(\.path) == ["/start", "/hop"])
    #expect(other.requests.isEmpty)
  }

  @Test
  func stampedRequestStopsAfterTenRedirects() async throws {
    let server = LoopbackHTTPServer { _ in (307, "/loop") }
    defer { server.stop() }

    do {
      let _: [String: Bool] = try await client(baseUrl: server.baseUrl).request(
        "/loop", body: [String: String]())
      Issue.record("expected redirect refusal")
    } catch let error as TurnkeyRequestError {
      #expect(error == .redirectRefused(statusCode: 307, location: "/loop"))
    }

    #expect(server.requests.count == 11)
  }

  @Test
  func authProxyRequestFollowsSameOrigin307PreservingRequest() async throws {
    let server = LoopbackHTTPServer { path in
      path == "/start" ? (307, "/final") : (200, nil)
    }
    defer { server.stop() }
    let client = TurnkeyClient(
      authProxyConfigId: "config-id",
      organizationId: "org-id",
      authProxyUrl: server.baseUrl
    )

    let result: [String: Bool] = try await client.authProxyRequest(
      "/start", body: ["field": "value"])

    #expect(result["ok"] == true)
    let requests = server.requests
    #expect(requests.map(\.path) == ["/start", "/final"])
    #expect(requests.allSatisfy { $0.method == "POST" })
    #expect(!requests[0].body.isEmpty)
    #expect(Set(requests.map(\.body)).count == 1)
    #expect(requests.allSatisfy { $0.headers["x-auth-proxy-config-id"] == "config-id" })
  }

  @Test
  func authProxyRequestRefusesCrossOriginRedirect() async throws {
    let other = LoopbackHTTPServer { _ in (200, nil) }
    defer { other.stop() }
    let crossOriginTarget = "\(other.baseUrl)/final"
    let server = LoopbackHTTPServer { _ in (308, crossOriginTarget) }
    defer { server.stop() }
    let client = TurnkeyClient(
      authProxyConfigId: "config-id",
      organizationId: "org-id",
      authProxyUrl: server.baseUrl
    )

    do {
      let _: [String: Bool] = try await client.authProxyRequest(
        "/start", body: ["field": "value"])
      Issue.record("expected redirect refusal")
    } catch let error as TurnkeyRequestError {
      #expect(error == .redirectRefused(statusCode: 308, location: crossOriginTarget))
    }

    #expect(server.requests.count == 1)
    #expect(other.requests.isEmpty)
  }

  @Test
  func effectiveOriginNormalizesCaseAndDefaultPorts() {
    let origin = SameOriginRedirectDelegate.effectiveOrigin
    #expect(origin(URL(string: "HTTPS://API.Example/path")!) == "https://api.example:443")
    #expect(
      origin(URL(string: "https://api.example/a")!)
        == origin(URL(string: "https://api.example:443/b")!))
    #expect(
      origin(URL(string: "http://api.example")!) != origin(URL(string: "https://api.example")!))
    #expect(
      origin(URL(string: "https://api.example:8443")!)
        != origin(URL(string: "https://api.example")!))
    #expect(origin(URL(string: "wss://api.example")!) == nil)
  }
}
