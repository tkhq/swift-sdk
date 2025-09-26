import Foundation

protocol AuthProxyResponseProtocol {
  var okPayload: Any? { get }
  var defaultCase: (statusCode: Int, rpcStatus: Components.Schemas.RpcStatus)? { get }
}
