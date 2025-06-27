import Foundation
import OpenAPIRuntime

extension TurnkeyClient {
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

  // if it's .ok we return its associated value
  if let child = mirror.children.first(where: { $0.label == "ok" }) {
    return child.value
  }

  // if it's .undocumented we map to TurnkeyError.apiError
  if let child = mirror.children.first(where: { $0.label == "undocumented" }),
    let tuple = child.value as? (statusCode: Int, payload: UndocumentedPayload)
  {

    var payloadData: Data?
    if let body = tuple.payload.body {
      payloadData = try await Data(collecting: body, upTo: .max)
    }
    throw TurnkeyRequestError.apiError(statusCode: tuple.statusCode, payload: payloadData)
  }

  throw TurnkeyRequestError.invalidResponse
}
