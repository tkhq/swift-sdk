import Foundation

final class SameOriginRedirectDelegate: NSObject, URLSessionTaskDelegate {
  static let shared = SameOriginRedirectDelegate()

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    if let originalUrl = task.originalRequest?.url,
      let redirectUrl = request.url,
      Self.hasSameOrigin(originalUrl, redirectUrl)
    {
      completionHandler(request)
    } else {
      completionHandler(nil)
    }
  }

  static func hasSameOrigin(_ original: URL, _ target: URL) -> Bool {
    guard let originalScheme = original.scheme?.lowercased(),
      let targetScheme = target.scheme?.lowercased(),
      let originalHost = original.host?.lowercased(),
      let targetHost = target.host?.lowercased(),
      let originalPort = effectivePort(scheme: originalScheme, port: original.port),
      let targetPort = effectivePort(scheme: targetScheme, port: target.port)
    else {
      return false
    }
    return originalScheme == targetScheme && originalHost == targetHost
      && originalPort == targetPort
  }

  private static func effectivePort(scheme: String, port: Int?) -> Int? {
    if let port = port {
      return port
    }
    switch scheme {
    case "https":
      return 443
    case "http":
      return 80
    default:
      return nil
    }
  }
}
