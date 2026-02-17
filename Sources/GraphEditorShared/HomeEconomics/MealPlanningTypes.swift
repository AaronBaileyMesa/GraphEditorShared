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
    // High-level workflow tasks
    case plan       // Planning the meal
    case shop       // Shopping for ingredients
    case prep       // General meal preparation
    case cook       // Cooking the meal
    case assemble   // Assembly and plating
    case serve      // Serving
    case cleanup    // Post-meal cleanup

    // Detailed prep subtasks (for tacos)
    case prepMeat       // Brown/season meat
    case prepVegetables // Chop vegetables (lettuce, tomatoes, onions, cilantro)
    case prepSauces     // Prepare sauces (salsa, guacamole, sour cream)
    case prepShells     // Warm tortillas/shells
    case prepToppings   // Prepare additional toppings (cheese, etc.)

    // Detailed assembly subtasks (for tacos)
    case assemblySetup  // Set up assembly station
    case assemblyBuild  // Build individual tacos
    case assemblyPlate  // Final plating

    /// Whether this task type is a high-level workflow task
    public var isTopLevel: Bool {
        switch self {
        case .plan, .shop, .prep, .cook, .assemble, .serve, .cleanup:
            return true
        default:
            return false
        }
    }

    /// Parent task type for subtasks
    public var parentTaskType: TaskType? {
        switch self {
        case .prepMeat, .prepVegetables, .prepSauces, .prepShells, .prepToppings:
            return .prep
        case .assemblySetup, .assemblyBuild, .assemblyPlate:
            return .assemble
        default:
            return nil
        }
    }

    /// Display name for the task
    public var displayName: String {
        switch self {
        case .plan: return "Plan Meal"
        case .shop: return "Shop for Ingredients"
        case .prep: return "Prepare Ingredients"
        case .cook: return "Cook"
        case .assemble: return "Assemble & Plate"
        case .serve: return "Serve"
        case .cleanup: return "Clean Up"
        case .prepMeat: return "Prepare Meat"
        case .prepVegetables: return "Chop Vegetables"
        case .prepSauces: return "Prepare Sauces"
        case .prepShells: return "Warm Shells"
        case .prepToppings: return "Prepare Toppings"
        case .assemblySetup: return "Setup Assembly Station"
        case .assemblyBuild: return "Build Tacos"
        case .assemblyPlate: return "Plate & Garnish"
        }
    }
}

/// Task status for workflow tracking
@available(iOS 16.0, watchOS 9.0, *)
public enum TaskStatus: String, Codable, CaseIterable {
    case pending
    case inProgress
    case completed
    case skipped
    case blocked    // Task cannot proceed due to dependency
    case declined   // User explicitly declined this task
}

/// Protein type for taco meals
@available(iOS 16.0, watchOS 9.0, *)
public enum ProteinType: String, Codable, CaseIterable {
    case beef
    case chicken
}

/// Shell/tortilla type for tacos
@available(iOS 16.0, watchOS 9.0, *)
public enum ShellType: String, Codable, CaseIterable {
    case crunchy        // Crispy hard shell (6" × 3")
    case softFlour      // Soft flour tortilla (8" diameter)
    case softCorn       // Soft corn tortilla (5" diameter)
    
    public var displayName: String {
        switch self {
        case .crunchy: return "Crunchy Shell"
        case .softFlour: return "Soft Flour Tortilla"
        case .softCorn: return "Soft Corn Tortilla"
        }
    }
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
