import Foundation
import OpenAPIRuntime

extension AuthProxyClient {
  @inline(__always)
  internal func call<RawEnum, Ok>(
    _ perform: () async throws -> RawEnum
  ) async throws -> Ok {
    let raw = try await perform()
    return try await unwrapOK(raw) as! Ok
  }
}

@inline(__always)
func unwrapOK<OutputEnum>(_ output: OutputEnum) async throws -> Any {
  let mirror = Mirror(reflecting: output)

  if let child = mirror.children.first(where: { $0.label == "ok" }) {
    return child.value
  }

  if let child = mirror.children.first(where: { $0.label == "undocumented" }),
    let tuple = child.value as? (statusCode: Int, payload: UndocumentedPayload)
  {

    var payloadData: Data?
    if let body = tuple.payload.body {
      payloadData = try await Data(collecting: body, upTo: .max)
    }
    throw AuthProxyRequestError.apiError(statusCode: tuple.statusCode, payload: payloadData)
  }

  throw AuthProxyRequestError.invalidResponse
}

public enum AuthProxyRequestError: Error {
  case invalidResponse
  case apiError(statusCode: Int, payload: Data?)
}
