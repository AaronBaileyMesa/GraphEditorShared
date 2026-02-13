//
//  PreferenceValue.swift
//  GraphEditorShared
//
//  Polymorphic value type for storing decision tree preferences
//

import Foundation

/// A polymorphic value that can represent different types of preference data
public enum PreferenceValue: Codable, Equatable, Hashable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case stringArray([String])
    
    /// Human-readable representation of the value
    public var displayString: String {
        switch self {
        // swiftlint:disable:next identifier_name
        case .string(let s):
            return s
        // swiftlint:disable:next identifier_name
        case .number(let n):
            // Format with up to 2 decimal places, removing trailing zeros
            let formatted = String(format: "%.2f", n)
            if let doubleValue = Double(formatted) {
                return doubleValue.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", doubleValue)
                    : formatted
            }
            return formatted
        // swiftlint:disable:next identifier_name
        case .boolean(let b):
            return b ? "Yes" : "No"
        case .stringArray(let arr):
            return arr.joined(separator: ", ")
        }
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case type
        case value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "string":
            let value = try container.decode(String.self, forKey: .value)
            self = .string(value)
        case "number":
            let value = try container.decode(Double.self, forKey: .value)
            self = .number(value)
        case "boolean":
            let value = try container.decode(Bool.self, forKey: .value)
            self = .boolean(value)
        case "stringArray":
            let value = try container.decode([String].self, forKey: .value)
            self = .stringArray(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown PreferenceValue type: \(type)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .string(let value):
            try container.encode("string", forKey: .type)
            try container.encode(value, forKey: .value)
        case .number(let value):
            try container.encode("number", forKey: .type)
            try container.encode(value, forKey: .value)
        case .boolean(let value):
            try container.encode("boolean", forKey: .type)
            try container.encode(value, forKey: .value)
        case .stringArray(let value):
            try container.encode("stringArray", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}
