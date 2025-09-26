import Foundation

extension AuthProxyClient {
  @inline(__always)
  internal func call<RawEnum, Ok>(
    _ perform: () async throws -> RawEnum
  ) async throws -> Ok {
    try await AuthProxyCapturedResponse.$storage.withValue(CapturedResponseStorage()) {
      do {
        let raw = try await perform()
        AuthProxyCapturedResponse.storage?.last = nil
        return try unwrapOK(raw) as! Ok
      } catch let error as AuthProxyRequestError {
        throw error
      } catch {
        if let captured = AuthProxyCapturedResponse.storage?.last {
          let payload = captured.body.isEmpty ? nil : captured.body
          throw AuthProxyRequestError.apiError(
            statusCode: captured.statusCode,
            payload: payload
          )
        }
        // No captured HTTP response: this is a transport-layer failure
        // (e.g., URLError like timeout/offline). Wrap consistently so callers
        // can branch without depending on underlying transport types.
        throw AuthProxyRequestError.transport(underlying: error)
      }
    }
  }
}

@inline(__always)
func unwrapOK<OutputEnum>(_ output: OutputEnum) throws -> Any {
  if let response = output as? AuthProxyResponseProtocol {
    if let ok = response.okPayload {
      return ok
    }
    if let (statusCode, rpcStatus) = response.defaultCase {
      let payload = try? JSONEncoder().encode(rpcStatus)
      throw AuthProxyRequestError.apiError(statusCode: statusCode, payload: payload)
    }
  }

  if let captured = AuthProxyCapturedResponse.storage?.last {
    let payload = captured.body.isEmpty ? nil : captured.body
    throw AuthProxyRequestError.apiError(statusCode: captured.statusCode, payload: payload)
  }

  throw AuthProxyRequestError.invalidResponse
}

public enum AuthProxyRequestError: Error {
  case invalidResponse
  case apiError(statusCode: Int, payload: Data?)
  case transport(underlying: Error)
}
