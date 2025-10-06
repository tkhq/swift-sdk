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

  if let child = mirror.children.first(where: { $0.label == "ok" }) {
    return child.value
  }

  for child in mirror.children {
    if let tuple = child.value as? (statusCode: Int, payload: UndocumentedPayload) {
      var payloadData: Data?
      if let body = tuple.payload.body {
        payloadData = try await Data(collecting: body, upTo: .max)
      }
      let error = TurnkeyRequestError.apiError(statusCode: tuple.statusCode, payload: payloadData)
      throw error
    }

    if let tuple = child.value as? (Int?, UndocumentedPayload?) {
      var payloadData: Data?
      if let body = tuple.1?.body {
        payloadData = try await Data(collecting: body, upTo: .max)
      }
      let error = TurnkeyRequestError.apiError(statusCode: tuple.0, payload: payloadData)
      throw error
    }
  }

  throw TurnkeyRequestError.invalidResponse
}
