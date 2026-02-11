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
        }
    }
}
