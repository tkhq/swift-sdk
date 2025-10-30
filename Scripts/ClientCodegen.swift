#!/usr/bin/env swift

import Foundation

// MARK: - Configuration

let SOURCE_DIRECTORY = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

let PUBLIC_API_SWAGGER_PATH = SOURCE_DIRECTORY
    .appendingPathComponent("Sources/TurnkeyTypes/Resources/Resources/public_api.swagger.json")

let AUTH_PROXY_SWAGGER_PATH = SOURCE_DIRECTORY
    .appendingPathComponent("Sources/TurnkeyTypes/Resources/Resources/auth_proxy.swagger.json")

let PUBLIC_OUTPUT_PATH = SOURCE_DIRECTORY
    .appendingPathComponent("Sources/TurnkeyHttp/Public/TurnkeyClient+Public.swift")

let AUTHPROXY_OUTPUT_PATH = SOURCE_DIRECTORY
    .appendingPathComponent("Sources/TurnkeyHttp/Public/TurnkeyClient+AuthProxy.swift")

// Activity types that have versioned variants
let VERSIONED_ACTIVITY_TYPES: [String: String] = [
    "ACTIVITY_TYPE_CREATE_AUTHENTICATORS": "ACTIVITY_TYPE_CREATE_AUTHENTICATORS_V2",
    "ACTIVITY_TYPE_CREATE_API_KEYS": "ACTIVITY_TYPE_CREATE_API_KEYS_V2",
    "ACTIVITY_TYPE_CREATE_POLICY": "ACTIVITY_TYPE_CREATE_POLICY_V3",
    "ACTIVITY_TYPE_CREATE_PRIVATE_KEYS": "ACTIVITY_TYPE_CREATE_PRIVATE_KEYS_V2",
    "ACTIVITY_TYPE_CREATE_SUB_ORGANIZATION": "ACTIVITY_TYPE_CREATE_SUB_ORGANIZATION_V7",
    "ACTIVITY_TYPE_CREATE_USERS": "ACTIVITY_TYPE_CREATE_USERS_V3",
    "ACTIVITY_TYPE_SIGN_RAW_PAYLOAD": "ACTIVITY_TYPE_SIGN_RAW_PAYLOAD_V2",
    "ACTIVITY_TYPE_SIGN_TRANSACTION": "ACTIVITY_TYPE_SIGN_TRANSACTION_V2",
    "ACTIVITY_TYPE_EMAIL_AUTH": "ACTIVITY_TYPE_EMAIL_AUTH_V2",
    "ACTIVITY_TYPE_CREATE_READ_WRITE_SESSION": "ACTIVITY_TYPE_CREATE_READ_WRITE_SESSION_V2",
    "ACTIVITY_TYPE_UPDATE_POLICY": "ACTIVITY_TYPE_UPDATE_POLICY_V2",
    "ACTIVITY_TYPE_INIT_OTP_AUTH": "ACTIVITY_TYPE_INIT_OTP_AUTH_V2",
]

// Methods that have only optional parameters
let METHODS_WITH_ONLY_OPTIONAL_PARAMETERS = [
    "getActivities",
    "getApiKeys",
    "getOrganization",
    "getPolicies",
    "getPrivateKeys",
    "getSubOrgIds",
    "getUsers",
    "getWallets",
    "getWhoami",
    "listPrivateKeys",
]

// MARK: - Swagger Models

struct SwaggerSpec: Codable {
    let swagger: String
    let info: Info
    let paths: [String: PathItem]
    let definitions: [String: Definition]
    let tags: [Tag]?
    
    struct Info: Codable {
        let title: String
        let version: String
    }
    
    struct Tag: Codable {
        let name: String
        let description: String?
    }
    
    struct PathItem: Codable {
        let post: Operation?
        let get: Operation?
    }
    
    struct Operation: Codable {
        let operationId: String
        let summary: String?
        let description: String?
        let parameters: [Parameter]?
    }
    
    struct Parameter: Codable {
        let name: String
        let `in`: String
        let required: Bool?
        let schema: Box<Schema>?
    }
    
    struct Schema: Codable {
        let ref: String?
        let type: String?
        let items: Box<Schema>?
        let properties: [String: Box<Schema>]?
        
        private enum CodingKeys: String, CodingKey {
            case ref = "$ref"
            case type, items, properties
        }
    }
    
    struct Definition: Codable {
        let type: String?
        let properties: [String: Box<Schema>]?
        let required: [String]?
        let enumValues: [String]?
        
        private enum CodingKeys: String, CodingKey {
            case type, properties, required
            case enumValues = "enum"
        }
    }
}

// Box wrapper for recursive types
class Box<T: Codable>: Codable {
    let value: T
    
    init(_ value: T) {
        self.value = value
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(T.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct VersionInfo {
    let fullName: String
    let formattedKeyName: String
    let versionSuffix: String
}

// MARK: - Helper Functions

func loadSwaggerSpec(from url: URL) throws -> SwaggerSpec {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    return try decoder.decode(SwaggerSpec.self, from: data)
}

func camelCase(_ str: String) -> String {
    let parts = str.components(separatedBy: "_")
    guard let first = parts.first else { return str }
    let rest = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
    return ([first] + rest).joined()
}

func snakeCase(_ str: String) -> String {
    // Convert PascalCase/camelCase to snake_case
    var result = ""
    for (index, char) in str.enumerated() {
        if char.isUppercase && index > 0 {
            result += "_"
        }
        result += char.lowercased()
    }
    return result
}

func methodTypeFromMethodName(_ methodName: String) -> String {
    if ["approveActivity", "rejectActivity"].contains(methodName) {
        return "activityDecision"
    }
    if methodName.hasPrefix("get") || methodName.hasPrefix("list") || methodName.hasPrefix("test") {
        return "query"
    }
    return "activity"
}

// Helper that extracts latest versions (matching JS extractLatestVersions)
func extractLatestVersions(definitions: [String: SwaggerSpec.Definition]) -> [String: VersionInfo] {
    var latestVersions: [String: VersionInfo] = [:]
    
    // Regex to separate version prefix, base name, and optional version suffix
    let keyVersionRegex = try! NSRegularExpression(pattern: "^(v\\d+)([A-Z][A-Za-z0-9]*?)(V\\d+)?$")
    
    for key in definitions.keys {
        let range = NSRange(key.startIndex..<key.endIndex, in: key)
        guard let match = keyVersionRegex.firstMatch(in: key, range: range) else { continue }
        
        let fullName = key
        let baseNameRange = Range(match.range(at: 2), in: key)!
        let baseName = String(key[baseNameRange])
        
        var versionSuffix = ""
        if match.range(at: 3).location != NSNotFound,
           let versionRange = Range(match.range(at: 3), in: key) {
            versionSuffix = String(key[versionRange])
        }
        
        let formattedKeyName = String(baseName.prefix(1).lowercased()) + String(baseName.dropFirst()) + versionSuffix
        
        // Update if this is newer or first version
        if latestVersions[baseName] == nil || versionSuffix > (latestVersions[baseName]?.versionSuffix ?? "") {
            latestVersions[baseName] = VersionInfo(
                fullName: fullName,
                formattedKeyName: formattedKeyName,
                versionSuffix: versionSuffix
            )
        }
    }
    
    return latestVersions
}

// MARK: - Code Generation

func generatePublicClientFile(swagger: SwaggerSpec) -> String {
    var output = """
    // @generated by ClientCodegen. DO NOT EDIT BY HAND
    
    import Foundation
    import TurnkeyTypes
    
    public extension TurnkeyClient {
    
    """
    
    let namespace = swagger.tags?.first?.name ?? "PublicApiService"
    let latestVersions = extractLatestVersions(definitions: swagger.definitions)
    
    // Sort paths for consistent output
    let sortedPaths = swagger.paths.sorted { $0.key < $1.key }
    
    for (endpointPath, pathItem) in sortedPaths {
        guard let operation = pathItem.post else { continue }
        let operationId = operation.operationId
        
        // Remove namespace prefix
        let operationNameWithoutNamespace = operationId.replacingOccurrences(
            of: "\(namespace)_",
            with: ""
        )
        
        if operationNameWithoutNamespace == "NOOPCodegenAnchor" {
            continue
        }
        
        // Convert to camelCase method name
        let methodName = operationNameWithoutNamespace.prefix(1).lowercased() + 
                        operationNameWithoutNamespace.dropFirst()
        
        let methodType = methodTypeFromMethodName(methodName)
        let inputType = "T\(operationNameWithoutNamespace)Body"
        let responseType = "T\(operationNameWithoutNamespace)Response"
        
        // Add method documentation
        if let summary = operation.summary {
            output += "\n    /// \(summary)\n"
        }
        if let description = operation.description {
            output += "    /// \(description)\n"
        }
        
        let hasOptionalParams = METHODS_WITH_ONLY_OPTIONAL_PARAMETERS.contains(methodName)
        let defaultParam = hasOptionalParams ? " = .init()" : ""
        
        if methodType == "query" {
            // Query method
            output += """
                func \(methodName)(_ input: \(inputType)\(defaultParam)) async throws -> \(responseType) {
                    return try await request("\(endpointPath)", body: input)
                }
            
            
            """
        } else if methodType == "activity" {
            // Activity method - needs type, organizationId, timestampMs wrapping
            let unversionedActivityType = "ACTIVITY_TYPE_\(snakeCase(operationNameWithoutNamespace).uppercased())"
            let activityType = VERSIONED_ACTIVITY_TYPES[unversionedActivityType] ?? unversionedActivityType
            
            let resultKey = operationNameWithoutNamespace + "Result"
            let versionedResultKey = latestVersions[resultKey]?.formattedKeyName ?? camelCase(resultKey)
            
            output += """
                func \(methodName)(_ input: \(inputType)) async throws -> \(responseType) {
                    return try await activity("\(endpointPath)", body: input, activityType: "\(activityType)", resultKey: "\(versionedResultKey)")
                }
            
            
            """
        } else if methodType == "activityDecision" {
            // Activity decision method
            let unversionedActivityType = "ACTIVITY_TYPE_\(snakeCase(operationNameWithoutNamespace).uppercased())"
            let activityType = VERSIONED_ACTIVITY_TYPES[unversionedActivityType] ?? unversionedActivityType
            
            output += """
                func \(methodName)(_ input: \(inputType)) async throws -> \(responseType) {
                    return try await activityDecision("\(endpointPath)", body: input, activityType: "\(activityType)")
                }
            
            
            """
        }
    }
    
    output += "}\n"
    return output
}

func generateAuthProxyClientFile(swagger: SwaggerSpec) -> String {
    var output = """
    // @generated by ClientCodegen. DO NOT EDIT BY HAND
    
    import Foundation
    import TurnkeyTypes
    
    public extension TurnkeyClient {
    
    """
    
    let namespace = swagger.tags?.first?.name ?? "AuthProxyService"
    
    // Sort paths for consistent output
    let sortedPaths = swagger.paths.sorted { $0.key < $1.key }
    
    for (endpointPath, pathItem) in sortedPaths {
        guard let operation = pathItem.post else { continue }
        let operationId = operation.operationId
        
        // Remove namespace prefix
        let operationNameWithoutNamespace = operationId.replacingOccurrences(
            of: "\(namespace)_",
            with: ""
        )
        
        // Convert to camelCase with "proxy" prefix
        let methodName = "proxy" + 
                        operationNameWithoutNamespace.prefix(1).uppercased() + 
                        operationNameWithoutNamespace.dropFirst()
        
        let inputType = "ProxyT\(operationNameWithoutNamespace)Body"
        let responseType = "ProxyT\(operationNameWithoutNamespace)Response"
        
        // Add method documentation
        if let summary = operation.summary {
            output += "\n    /// \(summary)\n"
        }
        if let description = operation.description {
            output += "    /// \(description)\n"
        }
        
        let hasOptionalParams = METHODS_WITH_ONLY_OPTIONAL_PARAMETERS.contains(methodName)
        let defaultParam = hasOptionalParams ? " = .init()" : ""
        
        output += """
            func \(methodName)(_ input: \(inputType)\(defaultParam)) async throws -> \(responseType) {
                return try await authProxyRequest("\(endpointPath)", body: input)
            }
        
        
        """
    }
    
    output += "}\n"
    return output
}

// MARK: - Main

print("🚀 Starting Client Code Generation for Swift...")

do {
    print("📖 Reading Swagger specifications...")
    let publicSwagger = try loadSwaggerSpec(from: PUBLIC_API_SWAGGER_PATH)
    let authProxySwagger = try loadSwaggerSpec(from: AUTH_PROXY_SWAGGER_PATH)
    
    print("✅ Parsed Swagger specifications")
    print("   - Public API: \(publicSwagger.paths.count) endpoints")
    print("   - Auth Proxy: \(authProxySwagger.paths.count) endpoints")
    
    print("\n🔨 Generating client methods...")
    
    // Generate Public API client
    let publicClient = generatePublicClientFile(swagger: publicSwagger)
    try publicClient.write(to: PUBLIC_OUTPUT_PATH, atomically: true, encoding: .utf8)
    print("✅ Generated public client at: \(PUBLIC_OUTPUT_PATH.path)")
    
    // Generate Auth Proxy client
    let authProxyClient = generateAuthProxyClientFile(swagger: authProxySwagger)
    try authProxyClient.write(to: AUTHPROXY_OUTPUT_PATH, atomically: true, encoding: .utf8)
    print("✅ Generated auth proxy client at: \(AUTHPROXY_OUTPUT_PATH.path)")
    
    print("\n✨ Client generation complete!")
    
} catch {
    print("❌ Error: \(error)")
    exit(1)
}
