//
//  MealPlanningTypes.swift
//  GraphEditorShared
//
//  Domain types for meal planning and family participation tracking
//

import Foundation

/// Meal type categorization
@available(iOS 16.0, watchOS 9.0, *)
public enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
}

/// Task types for meal preparation workflow
@available(iOS 16.0, watchOS 9.0, *)
public enum TaskType: String, Codable, CaseIterable {
    case plan       // Planning the meal
    case shop       // Shopping for ingredients
    case prep       // Meal preparation (chopping, etc.)
    case cook       // Cooking the meal
    case serve      // Serving and plating
    case cleanup    // Post-meal cleanup
}

/// Task status for workflow tracking
@available(iOS 16.0, watchOS 9.0, *)
public enum TaskStatus: String, Codable, CaseIterable {
    case pending
    case inProgress
    case completed
    case skipped
}

/// Measurement units for ingredients
@available(iOS 16.0, watchOS 9.0, *)
public enum MeasurementUnit: String, Codable, CaseIterable {
    // Volume
    case teaspoon, tablespoon, cup, pint, quart, gallon
    case milliliter, liter

    // Weight
    case ounce, pound, gram, kilogram

    // Count
    case whole, piece, slice, clove, can, package

    // Other
    case pinch, dash, toTaste

    public var abbreviation: String {
        switch self {
        case .teaspoon: return "tsp"
        case .tablespoon: return "tbsp"
        case .cup: return "cup"
        case .pint: return "pt"
        case .quart: return "qt"
        case .gallon: return "gal"
        case .milliliter: return "ml"
        case .liter: return "L"
        case .ounce: return "oz"
        case .pound: return "lb"
        case .gram: return "g"
        case .kilogram: return "kg"
        case .whole: return ""
        case .piece: return "pc"
        case .slice: return "slice"
        case .clove: return "clove"
        case .can: return "can"
        case .package: return "pkg"
        case .pinch: return "pinch"
        case .dash: return "dash"
        case .toTaste: return "to taste"
        }
    }
}
