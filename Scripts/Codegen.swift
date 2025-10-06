#!/usr/bin/env swift
import Foundation

// ---------- Paths ----------
let publicTypesPath = "Generated/Public/Types.swift"
let authProxyTypesPath = "Generated/AuthProxy/Types.swift"
let outputPath = "Public/Components.swift"

// ---------- Utils ----------
func readFile(_ path: String) -> String {
  (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

/// Extract all top-level schema type names inside Components.Schemas
func extractTypeNames(from text: String) -> [String] {
  let lines = text.components(separatedBy: .newlines)
  var names: [String] = []
  var inSchemas = false
  var braceDepth = 0
  
  let declRegex = try! NSRegularExpression(
    pattern: #"\s*(?:@\w+\s+)*public\s+(?:indirect\s+)?(enum|struct|typealias)\s+([A-Za-z_][A-Za-z0-9_]*)\b"#
  )

  for line in lines {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    
    // Look for the start of Components.Schemas
    if trimmed == "public enum Components {" {
      continue
    }
    if trimmed.hasPrefix("public enum Schemas {") && !inSchemas {
      inSchemas = true
      braceDepth = 0
      continue
    }
    
    if inSchemas {
      // Count braces to track depth within Schemas
      for char in line {
        if char == "{" {
          braceDepth += 1
        } else if char == "}" {
          braceDepth -= 1
          if braceDepth < 0 {
            // We've exited the Schemas enum
            inSchemas = false
            break
          }
        }
      }
      
      // Check for type declarations regardless of brace depth
      // We want to capture them when they're declared, not when we're inside them
      if inSchemas {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        if let match = declRegex.firstMatch(in: line, options: [], range: range),
           let nameRange = Range(match.range(at: 2), in: line) {
          let name = String(line[nameRange])
          // Don't include CodingKeys enums, nested enums, or other internal types
          // Allow legitimate external types that start with lowercase but contain "_period_" or start with "v1_period_"
          let isLegitimateExternalType = name.contains("_period_") || name.hasPrefix("v1_period_")
          let isUppercaseType = name.first?.isUppercase == true
          
          if !name.contains("CodingKeys") && 
             !name.contains("_typePayload") && 
             !name.hasPrefix("_") &&
             (isUppercaseType || isLegitimateExternalType) {
            names.append(name)
          }
        }
      }
    }
  }

  return names
}

// ---------- Read & extract ----------
let pubText = readFile(publicTypesPath)
let apText  = readFile(authProxyTypesPath)

let publicNames    = extractTypeNames(from: pubText)
let authProxyNames = extractTypeNames(from: apText)

print("Found \(publicNames.count) public types")
print("Found \(authProxyNames.count) auth proxy types")

// ---------- Generate typealiases ----------
let publicAliases = publicNames.map { name in
  "        public typealias \(name) = TurnkeyPublicAPI.Components.Schemas.\(name)"
}

let authAliases = authProxyNames.map { name in
  "        public typealias Proxy\(name) = TurnkeyAuthProxyAPI.Components.Schemas.\(name)"
}

// ---------- Output ----------
let output = """
// Generated — do not edit directly.
// Combined schemas from Public and AuthProxy APIs

@_spi(Generated) import OpenAPIRuntime
import Foundation
import TurnkeyPublicAPI
import TurnkeyAuthProxyAPI

public enum Components {
    public enum Schemas {
\( (publicAliases + [""] + authAliases).joined(separator: "\n") )
    }
}
"""

// Ensure output dir & write
let outputDir = (outputPath as NSString).deletingLastPathComponent
try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
try output.write(toFile: outputPath, atomically: true, encoding: .utf8)

print("✅ Wrote Components.swift — merged \(publicNames.count) Public + \(authProxyNames.count) Proxy-prefixed AuthProxy typealiases")
