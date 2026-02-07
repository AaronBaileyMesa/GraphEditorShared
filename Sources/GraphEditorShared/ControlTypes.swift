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

    // Future: Value editor kinds (e.g., .toggleBool, .sliderDouble) for node content editing

    public var systemImage: String {
        switch self {
        case .addChild: return "plus.circle"
        case .edit: return "pencil"
        case .addEdge: return "arrow.right.circle"
        case .delete: return "trash"
        case .duplicate: return "doc.on.doc"
        case .addToggleChild: return "checklist"
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
        }
    }
}
