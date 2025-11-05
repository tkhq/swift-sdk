// Helper methods for making HTTP requests with TurnkeyTypes
// These replace the OpenAPI-generated operations

import Foundation
import TurnkeyStamper
import TurnkeyTypes

// Activity status constants
private let TERMINAL_ACTIVITY_STATUSES: Set<String> = [
  "ACTIVITY_STATUS_COMPLETED",
  "ACTIVITY_STATUS_FAILED",
  "ACTIVITY_STATUS_CONSENSUS_NEEDED",
  "ACTIVITY_STATUS_REJECTED",
]

extension TurnkeyClient {

  // MARK: - Query/Request Methods

  /// Make a simple HTTP request (for query methods)
  /// - Parameters:
  ///   - path: The API endpoint path
  ///   - body: The request body
  ///   - stampWith: Optional stamper to use instead of the client's default stamper
  internal func request<TBody: Codable, TResponse: Codable>(
    _ path: String,
    body: TBody,
    stampWith: Stamper? = nil
  ) async throws -> TResponse {
    let stamperToUse = stampWith ?? self.stamper
    guard let stamper = stamperToUse else {
      throw TurnkeyRequestError.clientNotConfigured("stamper not configured")
    }

    let fullUrl = URL(string: baseUrl + path)!
    let jsonData = try JSONEncoder().encode(body)
    let jsonString = String(data: jsonData, encoding: .utf8)!

    // Stamp the request
    let (stampHeaderName, stampHeaderValue) = try await stamper.stamp(payload: jsonString)

    // Build request
    var request = URLRequest(url: fullUrl)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(stampHeaderValue, forHTTPHeaderField: stampHeaderName)

    // Execute request
    let (data, response) = try await URLSession.shared.data(for: request)

    // Check response
    guard let httpResponse = response as? HTTPURLResponse else {
      throw TurnkeyRequestError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw TurnkeyRequestError.apiError(statusCode: httpResponse.statusCode, payload: data)
    }

    // Decode response
    let decoder = JSONDecoder()
    return try decoder.decode(TResponse.self, from: data)
  }

  // MARK: - Activity Methods

  /// Make an activity request (for activity methods that need polling)
  /// - Parameters:
  ///   - path: The API endpoint path
  ///   - body: The request body (should contain organizationId, timestampMs, and parameters)
  ///   - activityType: The activity type to add to the request
  ///   - resultKey: The key in the activity result to extract
  ///   - stampWith: Optional stamper to use instead of the client's default stamper
  internal func activity<TBody: Codable, TResponse: Codable>(
    _ path: String,
    body: TBody,
    activityType: String,
    resultKey: String,
    stampWith: Stamper? = nil
  ) async throws -> TResponse {
    let pollingDuration = Double(self.activityPoller.intervalMs) / 1000.0
    let maxRetries = self.activityPoller.numRetries

    // Wrap the body with the activity type
    let wrappedBody = try wrapActivityBody(body, activityType: activityType)

    // Helper to handle response data
    func handleResponse(_ data: Data) throws -> TResponse {
      // Check status first
      guard let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let activity = responseDict["activity"] as? [String: Any],
            let status = activity["status"] as? String else {
        throw TurnkeyRequestError.invalidResponse
      }

      if status == "ACTIVITY_STATUS_COMPLETED" {
        // Merge result[resultKey] with activity response
        return try mergeActivityResponse(data, resultKey: resultKey)
      }

      // For non-completed states, decode as-is
      return try JSONDecoder().decode(TResponse.self, from: data)
    }

    var attempts = 0

    // Recursive polling function
    func pollStatus(_ activityId: String) async throws -> TResponse {
      let pollBody = TGetActivityBody(activityId: activityId)
      
      // Make raw request to get Data
      let stamperToUse = stampWith ?? self.stamper
      guard let stamper = stamperToUse else {
        throw TurnkeyRequestError.clientNotConfigured("stamper not configured")
      }

      let fullUrl = URL(string: baseUrl + "/public/v1/query/get_activity")!
      let jsonData = try JSONEncoder().encode(pollBody)
      let jsonString = String(data: jsonData, encoding: .utf8)!
      let (stampHeaderName, stampHeaderValue) = try await stamper.stamp(payload: jsonString)

      var request = URLRequest(url: fullUrl)
      request.httpMethod = "POST"
      request.httpBody = jsonData
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(stampHeaderValue, forHTTPHeaderField: stampHeaderName)

      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
        throw TurnkeyRequestError.invalidResponse
      }

      if attempts > maxRetries {
        return try handleResponse(data)
      }

      attempts += 1

      // Check if we need to continue polling
      if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let activity = responseDict["activity"] as? [String: Any],
         let status = activity["status"] as? String,
         !TERMINAL_ACTIVITY_STATUSES.contains(status) {
        try await Task.sleep(nanoseconds: UInt64(pollingDuration * 1_000_000_000))
        return try await pollStatus(activityId)
      }

      return try handleResponse(data)
    }

    // Make initial request - get raw Data
    let stamperToUse = stampWith ?? self.stamper
    guard let stamper = stamperToUse else {
      throw TurnkeyRequestError.clientNotConfigured("stamper not configured")
    }

    let fullUrl = URL(string: baseUrl + path)!
    let jsonData = try JSONEncoder().encode(wrappedBody)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    let (stampHeaderName, stampHeaderValue) = try await stamper.stamp(payload: jsonString)

    var request = URLRequest(url: fullUrl)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(stampHeaderValue, forHTTPHeaderField: stampHeaderName)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw TurnkeyRequestError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw TurnkeyRequestError.apiError(statusCode: httpResponse.statusCode, payload: data)
    }

    // Check if we need to poll
    if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let activity = responseDict["activity"] as? [String: Any],
       let status = activity["status"] as? String,
       let activityId = activity["id"] as? String,
       !TERMINAL_ACTIVITY_STATUSES.contains(status) {
      return try await pollStatus(activityId)
    }

    return try handleResponse(data)
  }

  /// Wraps an activity body by extracting organizationId/timestampMs and adding the type field
  private func wrapActivityBody<TBody: Codable>(_ body: TBody, activityType: String) throws
    -> ActivityRequestWrapper
  {
    let encoder = JSONEncoder()
    let bodyData = try encoder.encode(body)
    var bodyDict = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]

    // Extract organizationId and timestampMs if present
    let organizationId = bodyDict["organizationId"] as? String
    let timestampMs =
      bodyDict["timestampMs"] as? String ?? String(Int(Date().timeIntervalSince1970 * 1000))

    // Remove organizationId and timestampMs from the body dict (they'll be at top level)
    bodyDict.removeValue(forKey: "organizationId")
    bodyDict.removeValue(forKey: "timestampMs")

    return ActivityRequestWrapper(
      type: activityType,
      timestampMs: timestampMs,
      organizationId: organizationId,
      parameters: AnyCodableDict(bodyDict)
    )
  }

  private func mergeActivityResponse<TResponse: Codable>(
    _ activityData: Data,
    resultKey: String
  ) throws -> TResponse {
    // Parse the activity response as a dictionary (working with raw JSON, not AnyCodable)
    guard var responseDict = try JSONSerialization.jsonObject(with: activityData) as? [String: Any],
          let activity = responseDict["activity"] as? [String: Any],
          let result = activity["result"] as? [String: Any],
          let specificResult = result[resultKey] as? [String: Any] else {
      throw TurnkeyRequestError.invalidResponse
    }

    // Merge: spread specificResult into top level, keep activity
    // TypeScript does: { ...result[resultKey], ...activityData }
    for (key, value) in specificResult {
      responseDict[key] = value
    }

    // Convert back to Data and decode to TResponse
    let mergedData = try JSONSerialization.data(withJSONObject: responseDict)
    return try JSONDecoder().decode(TResponse.self, from: mergedData)
  }

  // MARK: - Activity Decision Methods

  /// Make an activity decision request (approve/reject)
  /// - Parameters:
  ///   - path: The API endpoint path
  ///   - body: The request body
  ///   - stampWith: Optional stamper to use instead of the client's default stamper
  internal func activityDecision<TBody: Codable, TResponse: Codable>(
    _ path: String,
    body: TBody,
    activityType: String,
    stampWith: Stamper? = nil
  ) async throws -> TResponse {
    // Use the specified stamper for this request
    let activityData: TActivityResponse = try await request(path, body: body, stampWith: stampWith)

    // Merge activity.result with activityData
    // This mimics the JS: { ...activityData["activity"]["result"], ...activityData }
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    var activityDict =
      try JSONSerialization.jsonObject(
        with: encoder.encode(activityData)
      ) as! [String: Any]

    // Extract result and merge
    if let activity = activityDict["activity"] as? [String: Any],
      let result = activity["result"] as? [String: Any]
    {
      // Merge result into activityDict (result values take precedence)
      activityDict = activityDict.merging(result) { _, new in new }
    }

    // Convert back to TResponse
    let mergedData = try JSONSerialization.data(withJSONObject: activityDict)
    return try decoder.decode(TResponse.self, from: mergedData)
  }

  // MARK: - Auth Proxy Methods

  /// Make an auth proxy request
  internal func authProxyRequest<TBody: Codable, TResponse: Codable>(
    _ path: String,
    body: TBody
  ) async throws -> TResponse {
    guard let authProxyUrl = self.authProxyUrl,
      let authProxyConfigId = self.authProxyConfigId
    else {
      throw TurnkeyRequestError.clientNotConfigured(
        "authProxyUrl or authProxyConfigId not configured")
    }

    let fullUrl = URL(string: authProxyUrl + path)!
    let jsonData = try JSONEncoder().encode(body)

    // Build request
    var request = URLRequest(url: fullUrl)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(authProxyConfigId, forHTTPHeaderField: "X-Auth-Proxy-Config-ID")

    // Execute request
    let (data, response) = try await URLSession.shared.data(for: request)

    // Check response
    guard let httpResponse = response as? HTTPURLResponse else {
      throw TurnkeyRequestError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw TurnkeyRequestError.apiError(statusCode: httpResponse.statusCode, payload: data)
    }

    // Decode response
    let decoder = JSONDecoder()
    return try decoder.decode(TResponse.self, from: data)
  }
}

// MARK: - Activity Request Wrapper Types

/// Wrapper for activity requests that adds type, timestampMs, organizationId, and parameters
private struct ActivityRequestWrapper: Codable {
  let type: String
  let timestampMs: String
  let organizationId: String?
  let parameters: AnyCodableDict
}

/// Helper for encoding/decoding arbitrary dictionaries
private struct AnyCodableDict: Codable {
  let value: [String: Any]

  init(_ value: [String: Any]) {
    self.value = value
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let dict = try container.decode([String: AnyCodable].self)
    value = dict.mapValues { $0.value }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    // Convert [String: Any] to [String: AnyCodable] for encoding
    var codableDict: [String: AnyCodable] = [:]
    for (key, val) in value {
      codableDict[key] = AnyCodable(val)
    }
    try container.encode(codableDict)
  }
}

// MARK: - Helper Types for Activity Handling

// Helper types for activity handling
private struct TActivityResponse: Codable {
  let activity: Activity

  struct Activity: Codable {
    let id: String
    let status: String
    let result: [String: AnyCodable]?
  }
}

private struct TGetActivityBody: Codable {
  let activityId: String
}

// Helper for decoding any JSON value
private struct AnyCodable: Codable {
  let value: Any

  init(_ value: Any) {
    self.value = value
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    // Check bool BEFORE int to prevent bool->int conversion
    if let bool = try? container.decode(Bool.self) {
      value = bool
    } else if let int = try? container.decode(Int.self) {
      value = int
    } else if let double = try? container.decode(Double.self) {
      value = double
    } else if let string = try? container.decode(String.self) {
      value = string
    } else if let dict = try? container.decode([String: AnyCodable].self) {
      value = dict.mapValues { $0.value }
    } else if let array = try? container.decode([AnyCodable].self) {
      value = array.map { $0.value }
    } else {
      value = NSNull()
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch value {
    // Check bool BEFORE int to prevent bool->int conversion during encoding
    case let bool as Bool:
      try container.encode(bool)
    case let int as Int:
      try container.encode(int)
    case let double as Double:
      try container.encode(double)
    case let string as String:
      try container.encode(string)
    case let dict as [String: Any]:
      // Convert to [String: AnyCodable] for encoding
      try container.encode(dict.mapValues { AnyCodable($0) })
    case let array as [Any]:
      // Convert to [AnyCodable] for encoding
      try container.encode(array.map { AnyCodable($0) })
    case is NSNull:
      try container.encodeNil()
    default:
      throw EncodingError.invalidValue(
        value, EncodingError.Context(codingPath: [], debugDescription: "Invalid value"))
    }
  }
}
