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
    
    // Taco category controls (navigation)
    case selectProtein   // Show protein selection controls (TacoNode)
    case selectShell     // Show shell selection controls (TacoNode)
    case selectToppings  // Show toppings selection controls (TacoNode)
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
    case toggleJalapeños // Toggle jalapeños topping (TacoNode)
    case toggleHotSauce  // Toggle hot sauce topping (TacoNode)

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
        
        // Taco category controls
        case .selectProtein: return "fork.knife"
        case .selectShell: return "circlebadge.fill"
        case .selectToppings: return "list.bullet"
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
        }
    }
    
    /// System image name for rendering in ControlNode's renderView (filled variants)
    public var renderIcon: String {
        switch self {
        case .addChild: return "plus.circle.fill"
        case .addEdge: return "arrow.right.circle.fill"
        case .edit: return "pencil"
        case .delete: return "trash.fill"
        case .duplicate: return "doc.on.doc.fill"
        case .addToggleChild: return "checklist"
        case .toggleExpand: return "chevron.right"
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
        
        // Taco category controls
        case .selectProtein: return "fork.knife"
        case .selectShell: return "circlebadge.fill"
        case .selectToppings: return "list.bullet"
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
        }
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
        
        // Taco topping options
        case .toggleLettuce: return "Let"
        case .toggleTomatoes: return "Tom"
        case .toggleCheese: return "Che"
        case .toggleSourCream: return "SC"
        case .toggleGuacamole: return "Gua"
        case .toggleSalsa: return "Sal"
        case .toggleOnions: return "Oni"
        case .toggleCilantro: return "Cil"
        case .toggleJalapeños: return "Jal"
        case .toggleHotSauce: return "Hot"
        
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
            
        // Taco category controls
        case .selectProtein:
            return .brown  // Protein category - brown
        case .selectShell:
            return .yellow  // Shell category - yellow
        case .selectToppings:
            return .green  // Toppings category - green
        case .backToCategories:
            return .gray  // Back navigation - gray
            
        // Taco configuration controls - gray for unselected, will be overridden based on selection state
        case .toggleBeef, .toggleChicken:
            return .brown  // Protein choices - brown
        case .toggleCrunchyShell, .toggleSoftFlourShell, .toggleSoftCornShell:
            return .yellow  // Shell choices - yellow
        case .toggleLettuce, .toggleTomatoes, .toggleCheese, .toggleSourCream,
             .toggleGuacamole, .toggleSalsa, .toggleOnions, .toggleCilantro,
             .toggleJalapeños, .toggleHotSauce:
            return .green  // Toppings - green
        }
    }
}
