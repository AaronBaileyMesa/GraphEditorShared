//
//  ControlTypes.swift
//  GraphEditorShared
//
//  Created by handcart on 11/28/25.
//

import Foundation

@available(iOS 16.0, watchOS 6.0, *)
public enum ControlKind: String, Codable, CaseIterable {
    case undo
    case redo
    case configMode
    case addChild
    case deleteNode
    case toggleExpansion  // optional future use
    
    public var systemImage: String {
        switch self {
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .configMode: return "gear"
        case .addChild: return "plus.circle"
        case .deleteNode: return "trash"
        case .toggleExpansion: return "chevron.up.chevron.down"
        }
    }
}
