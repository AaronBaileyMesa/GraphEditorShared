//
//  ControlTypes.swift
//  GraphEditorShared
//
//  Created by handcart on 11/28/25.
//

import Foundation

@available(iOS 16.0, watchOS 6.0, *)
public enum ControlKind: String, Codable, CaseIterable {

    case addChild  // Adds a child node of the same type as parent
    case edit
    case addEdge
    
    // Future: Value editor kinds (e.g., .toggleBool, .sliderDouble) for node content editing
    
    public var systemImage: String {
        switch self {
        case .addChild: return "plus.circle"
        case .edit: return "pencil"
        case .addEdge: return "arrow.right.circle"
        }
    }
}
