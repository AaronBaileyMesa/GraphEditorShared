//
//  ControlTypes.swift
//  GraphEditorShared
//
//  Created by handcart on 11/28/25.
//

import Foundation
import SwiftUI

@available(iOS 16.0, watchOS 6.0, *)
public enum ControlKind: String, Codable, CaseIterable {

    case addChild  // Adds a child node of the same type as parent
    case edit
    case addEdge
    case delete  // Deletes the node
    case duplicate  // Duplicates the node
    case addToggleChild  // Adds a toggle node child
    case toggleExpand  // Toggles expand/collapse for collapsible nodes
    case openMenu  // Opens the node's specialized menu view
    
    // Workflow-specific controls for meal planning
    case startWorkflow  // Start workflow execution (MealNode)
    case stopWorkflow   // Stop workflow execution (MealNode)
    case completeTask   // Complete current task and advance (MealNode)
    case startTask      // Start a pending task (TaskNode)
    case blockTask      // Mark task as blocked (TaskNode)
    case unblockTask    // Unblock a blocked task (TaskNode)
    case declineTask    // Decline a task (TaskNode)
    case resetTask      // Reset completed/declined task (TaskNode)
    case addShopTask    // Add shopping task (MealNode)
    case addPrepTask    // Add prep task (MealNode)
    case addCookTask    // Add cook task (MealNode)
    case addRecipe      // Add recipe to meal (MealNode)
    case scaleRecipe    // Scale recipe based on guests (RecipeNode)
    case createTacoOrder // Create a taco order for a person (PersonNode)

    // PersonNode controls
    case linkContact     // Link a contact to PersonNode
    case editPreferences // Edit dietary preferences for PersonNode

    // RootNode creation controls
    case addPersonNode   // Create a PersonNode from RootNode
    case addMealNode     // Create a MealNode from RootNode
    case addTacoNight    // Launch TacoNightWizard from RootNode
    case viewDashboard   // Navigate to Dashboard view from RootNode
    
    // Taco category controls (navigation)
    case selectProtein   // Show protein selection controls (TacoNode)
    case selectShell     // Show shell selection controls (TacoNode)
    case selectToppings  // Show toppings category controls (TacoNode)
    case selectVeggies      // Show veggie toppings: tomato, lettuce, onion, jalapeño, radishes
    case selectCreamy       // Show creamy toppings: cheese, sour cream, guacamole
    case selectHerbsZest    // Show herb/zest toppings: cilantro, lime
    case selectFireKick     // Show heat toppings: hot sauce, pickled jalapeños
    case backToCategories // Return to category selection (TacoNode)

    // Taco configuration controls (detail level)
    case toggleBeef      // Toggle beef protein selection (TacoNode)
    case toggleChicken   // Toggle chicken protein selection (TacoNode)
    case toggleCrunchyShell // Toggle crunchy shell selection (TacoNode)
    case toggleSoftFlourShell // Toggle soft flour shell selection (TacoNode)
    case toggleSoftCornShell // Toggle soft corn shell selection (TacoNode)
    case toggleLettuce   // Toggle lettuce topping (TacoNode)
    case toggleTomatoes  // Toggle tomatoes topping (TacoNode)
    case toggleCheese    // Toggle cheese topping (TacoNode)
    case toggleSourCream // Toggle sour cream topping (TacoNode)
    case toggleGuacamole // Toggle guacamole topping (TacoNode)
    case toggleSalsa     // Toggle salsa topping (TacoNode)
    case toggleOnions    // Toggle onions topping (TacoNode)
    case toggleCilantro  // Toggle cilantro topping (TacoNode)
    case toggleJalapeños // Toggle fresh jalapeño topping (TacoNode)
    case toggleHotSauce  // Toggle hot sauce topping (TacoNode)
    case toggleRadishes      // Toggle radishes topping (TacoNode)
    case toggleLime          // Toggle lime slice topping (TacoNode)
    case togglePickledJalapeños // Toggle pickled jalapeños topping (TacoNode)

    // Future: Value editor kinds (e.g., .toggleBool, .sliderDouble) for node content editing

    public var systemImage: String {
        switch self {
        case .addChild: return "plus.circle"
        case .edit: return "pencil"
        case .addEdge: return "arrow.right.circle"
        case .delete: return "trash"
        case .duplicate: return "doc.on.doc"
        case .addToggleChild: return "checklist"
        case .toggleExpand: return "chevron.right"  // Will rotate based on state
        case .openMenu: return "list.bullet.circle.fill"
        
        // Workflow controls
        case .startWorkflow: return "play.fill"
        case .stopWorkflow: return "stop.fill"
        case .completeTask: return "checkmark.circle.fill"
        case .startTask: return "play.circle.fill"
        case .blockTask: return "exclamationmark.triangle.fill"
        case .unblockTask: return "play.circle.fill"
        case .declineTask: return "xmark.circle.fill"
        case .resetTask: return "arrow.counterclockwise"
        case .addShopTask: return "cart.fill"
        case .addPrepTask: return "fork.knife"
        case .addCookTask: return "flame.fill"
        case .addRecipe: return "book.fill"
        case .scaleRecipe: return "person.2.fill"
        case .createTacoOrder: return "takeoutbag.and.cup.and.straw.fill"

        // PersonNode controls
        case .linkContact: return "person.crop.circle.badge.plus"
        case .editPreferences: return "pencil.circle"

        // RootNode creation controls
        case .addPersonNode: return "person.circle"
        case .addMealNode: return "fork.knife.circle"
        case .addTacoNight: return "takeoutbag.and.cup.and.straw"
        case .viewDashboard: return "chart.bar.fill"
        
        // Taco category controls
        case .selectProtein: return "fork.knife"
        case .selectShell: return "circlebadge.fill"
        case .selectToppings: return "leaf"
        case .selectVeggies: return "leaf"
        case .selectCreamy: return "drop"
        case .selectHerbsZest: return "sparkles"
        case .selectFireKick: return "flame"
        case .backToCategories: return "chevron.left"

        // Taco configuration controls - using text labels in renderIcon
        case .toggleBeef: return "circle"
        case .toggleChicken: return "circle"
        case .toggleCrunchyShell: return "circle"
        case .toggleSoftFlourShell: return "circle"
        case .toggleSoftCornShell: return "circle"
        case .toggleLettuce: return "circle"
        case .toggleTomatoes: return "circle"
        case .toggleCheese: return "circle"
        case .toggleSourCream: return "circle"
        case .toggleGuacamole: return "circle"
        case .toggleSalsa: return "circle"
        case .toggleOnions: return "circle"
        case .toggleCilantro: return "circle"
        case .toggleJalapeños: return "circle"
        case .toggleHotSauce: return "circle"
        case .toggleRadishes: return "circle"
        case .toggleLime: return "circle"
        case .togglePickledJalapeños: return "circle"
        }
    }
    
    /// System image name for rendering in ControlNode's renderView (filled variants)
    /// For toggleExpand, use renderIcon(isExpanded:) to get the correct directional chevron
    public var renderIcon: String {
        switch self {
        case .addChild: return "plus.circle.fill"
        case .addEdge: return "arrow.right.circle.fill"
        case .edit: return "pencil"
        case .delete: return "trash.fill"
        case .duplicate: return "doc.on.doc.fill"
        case .addToggleChild: return "checklist"
        case .toggleExpand: return "chevron.down"  // Default to down (expanded state)
        case .openMenu: return "list.bullet.circle.fill"
        
        // Workflow controls
        case .startWorkflow: return "play.fill"
        case .stopWorkflow: return "stop.fill"
        case .completeTask: return "checkmark.circle.fill"
        case .startTask: return "play.circle.fill"
        case .blockTask: return "exclamationmark.triangle.fill"
        case .unblockTask: return "play.circle.fill"
        case .declineTask: return "xmark.circle.fill"
        case .resetTask: return "arrow.counterclockwise"
        case .addShopTask: return "cart.fill"
        case .addPrepTask: return "fork.knife"
        case .addCookTask: return "flame.fill"
        case .addRecipe: return "book.fill"
        case .scaleRecipe: return "person.2.fill"
        case .createTacoOrder: return "takeoutbag.and.cup.and.straw.fill"

        // PersonNode controls
        case .linkContact: return "person.crop.circle.badge.plus"
        case .editPreferences: return "pencil.circle.fill"

        // RootNode creation controls
        case .addPersonNode: return "person.circle.fill"
        case .addMealNode: return "fork.knife.circle.fill"
        case .addTacoNight: return "takeoutbag.and.cup.and.straw.fill"
        case .viewDashboard: return "chart.bar.fill"
        
        // Taco category controls
        case .selectProtein: return "fork.knife"
        case .selectShell: return "circlebadge.fill"
        case .selectToppings: return "leaf.fill"
        case .selectVeggies: return "leaf.fill"
        case .selectCreamy: return "drop.fill"
        case .selectHerbsZest: return "sparkles"
        case .selectFireKick: return "flame.fill"
        case .backToCategories: return "chevron.left.circle.fill"

        // Taco configuration controls
        case .toggleBeef: return "circle.fill"
        case .toggleChicken: return "circle.fill"
        case .toggleCrunchyShell: return "circle.fill"
        case .toggleSoftFlourShell: return "circle.fill"
        case .toggleSoftCornShell: return "circle.fill"
        case .toggleLettuce: return "circle.fill"
        case .toggleTomatoes: return "circle.fill"
        case .toggleCheese: return "circle.fill"
        case .toggleSourCream: return "circle.fill"
        case .toggleGuacamole: return "circle.fill"
        case .toggleSalsa: return "circle.fill"
        case .toggleOnions: return "circle.fill"
        case .toggleCilantro: return "circle.fill"
        case .toggleJalapeños: return "circle.fill"
        case .toggleHotSauce: return "circle.fill"
        case .toggleRadishes: return "circle.fill"
        case .toggleLime: return "circle.fill"
        case .togglePickledJalapeños: return "circle.fill"
        }
    }
    
    /// Returns the appropriate icon for toggleExpand based on the owner node's expansion state
    /// - Parameter isExpanded: Whether the owner node is currently expanded
    /// - Returns: Chevron pointing down if expanded, right if collapsed
    public func renderIcon(isExpanded: Bool) -> String {
        if self == .toggleExpand {
            return isExpanded ? "chevron.down" : "chevron.right"
        }
        return renderIcon
    }
    
    /// Text label for controls that need text display (like taco options)
    public var textLabel: String? {
        switch self {
        // Taco protein options
        case .toggleBeef: return "🥩"
        case .toggleChicken: return "🍗"
        
        // Taco shell options
        case .toggleCrunchyShell: return "Crunchy"
        case .toggleSoftFlourShell: return "Soft Flour"
        case .toggleSoftCornShell: return "Soft Corn"
        
        // Taco topping sub-categories
        case .selectVeggies: return "🥗"
        case .selectCreamy: return "🧀"
        case .selectHerbsZest: return "🌿"
        case .selectFireKick: return "🌶️"

        // Taco topping options
        case .toggleLettuce: return "🥬"
        case .toggleTomatoes: return "🍅"
        case .toggleCheese: return "🧀"
        case .toggleSourCream: return "🥛"
        case .toggleGuacamole: return "🥑"
        case .toggleSalsa: return "🫙"
        case .toggleOnions: return "🧅"
        case .toggleCilantro: return "🌿"
        case .toggleJalapeños: return "🫑"
        case .toggleHotSauce: return "🌶️"
        case .toggleRadishes: return "🔴"
        case .toggleLime: return "🍋"
        case .togglePickledJalapeños: return "🫙"

        default: return nil
        }
    }

    /// Short word label shown below the emoji on control nodes for legibility
    public var shortLabel: String? {
        switch self {
        // Topping sub-categories
        case .selectVeggies: return "Veggies"
        case .selectCreamy: return "Creamy"
        case .selectHerbsZest: return "Herbs"
        case .selectFireKick: return "Fire"

        // Topping toggles
        case .toggleLettuce: return "Lettuce"
        case .toggleTomatoes: return "Tomato"
        case .toggleCheese: return "Cheese"
        case .toggleSourCream: return "Crema"
        case .toggleGuacamole: return "Guac"
        case .toggleSalsa: return "Salsa"
        case .toggleOnions: return "Onion"
        case .toggleCilantro: return "Cilantro"
        case .toggleJalapeños: return "Jalapeño"
        case .toggleHotSauce: return "Hot Sauce"
        case .toggleRadishes: return "Radish"
        case .toggleLime: return "Lime"
        case .togglePickledJalapeños: return "Pickled"

        default: return nil
        }
    }
    
    /// Color coding by action type for better visual differentiation
    public var color: Color {
        switch self {
        case .addChild, .addToggleChild:
            return .green  // Creation actions - green
        case .addEdge:
            return .blue  // Connection action - blue
        case .duplicate:
            return .cyan  // Duplication - cyan (between creation and connection)
        case .edit:
            return .orange  // Edit action - orange/yellow
        case .delete:
            return .red  // Destructive action - red
        case .toggleExpand:
            return .purple  // Toggle action - purple
        case .openMenu:
            return .blue  // Menu action - blue
            
        // Workflow control colors
        case .startWorkflow, .startTask, .unblockTask:
            return .green  // Start actions - green
        case .stopWorkflow:
            return .red  // Stop action - red
        case .completeTask:
            return .green  // Completion - green
        case .blockTask:
            return .orange  // Warning/block - orange
        case .declineTask:
            return .red.opacity(0.8)  // Decline - muted red
        case .resetTask:
            return .blue  // Reset - blue
        case .addShopTask, .addPrepTask, .addCookTask:
            return .green  // Task creation - green
        case .addRecipe:
            return .cyan  // Recipe addition - cyan
        case .scaleRecipe:
            return .blue  // Scale operation - blue
        case .createTacoOrder:
            return .orange  // Taco order creation - orange (taco-themed)

        // PersonNode controls
        case .linkContact:
            return .purple  // Link contact - purple
        case .editPreferences:
            return .blue  // Edit preferences - blue

        // RootNode creation controls
        case .addPersonNode:
            return .green  // Person creation - green
        case .addMealNode:
            return .green  // Meal creation - green
        case .addTacoNight:
            return .orange  // TacoNight creation - orange (taco-themed)
        case .viewDashboard:
            return .blue  // Dashboard view - blue
            
        // Taco category controls
        case .selectProtein:
            return .brown  // Protein category - brown
        case .selectShell:
            return .yellow  // Shell category - yellow
        case .selectToppings:
            return .green  // Toppings category - green
        case .selectVeggies:
            return Color(red: 0.2, green: 0.65, blue: 0.25)  // Veggies - fresh green
        case .selectCreamy:
            return Color(red: 0.9, green: 0.75, blue: 0.3)   // Creamy - warm yellow
        case .selectHerbsZest:
            return Color(red: 0.15, green: 0.55, blue: 0.3)  // Herbs - cool green
        case .selectFireKick:
            return Color(red: 0.85, green: 0.25, blue: 0.1)  // Fire - red-orange
        case .backToCategories:
            return .gray  // Back navigation - gray

        // Taco configuration controls - colored by category
        case .toggleBeef, .toggleChicken:
            return .brown  // Protein choices - brown
        case .toggleCrunchyShell, .toggleSoftFlourShell, .toggleSoftCornShell:
            return .yellow  // Shell choices - yellow
        case .toggleLettuce, .toggleTomatoes, .toggleOnions, .toggleJalapeños, .toggleRadishes:
            return Color(red: 0.2, green: 0.65, blue: 0.25)  // Veggies - green
        case .toggleCheese, .toggleSourCream, .toggleGuacamole:
            return Color(red: 0.9, green: 0.75, blue: 0.3)   // Creamy - warm yellow
        case .toggleSalsa:
            return Color(red: 0.85, green: 0.25, blue: 0.1)  // Salsa - red
        case .toggleCilantro, .toggleLime:
            return Color(red: 0.15, green: 0.55, blue: 0.3)  // Herbs/zest - cool green
        case .toggleHotSauce, .togglePickledJalapeños:
            return Color(red: 0.85, green: 0.25, blue: 0.1)  // Fire - red-orange
        }
    }
}
