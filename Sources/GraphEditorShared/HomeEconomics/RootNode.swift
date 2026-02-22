//
//  RootNode.swift
//  GraphEditorShared
//
//  Root node for graph - always exists at (0,0), undeletable, unmovable
//

import SwiftUI
import Foundation

/// Root node that serves as the entry point for graph construction
@available(iOS 16.0, watchOS 9.0, *)
public struct RootNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint  // Always (0, 0)
    public var velocity: CGPoint  // Always zero
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Can have hierarchical children
    public var childOrder: [NodeID]

    // Root-specific properties
    public var name: String  // Editable display name (defaults to graph name)
    
    public var contents: [NodeContent] {
        get {
            [.string(name)]
        }
        set {
            // Extract name from contents if changed
            if case .string(let newName) = newValue.first {
                self = RootNode(
                    id: id,
                    label: label,
                    position: position,
                    velocity: velocity,
                    radius: radius,
                    isExpanded: isExpanded,
                    isCollapsible: isCollapsible,
                    children: children,
                    childOrder: childOrder,
                    name: newName
                )
            }
        }
    }
    
    public var displayRadius: CGFloat {
        radius * 1.5  // Larger than normal nodes
    }
    
    public var fillColor: Color {
        Color.gray.opacity(0.6)  // Light gray
    }
    
    public var typeDescriptor: NodeTypeDescriptor {
        RootNodeDescriptor(node: self)
    }
    
    public init(
        id: NodeID = UUID(),
        label: Int = -1,  // Special reserved label for root
        position: CGPoint = .zero,  // Always at origin
        velocity: CGPoint = .zero,  // Never moves
        radius: CGFloat = Constants.App.nodeModelRadius * 1.5,
        isExpanded: Bool = true,  // Always expanded to show controls
        isCollapsible: Bool = false,  // Cannot collapse
        children: [NodeID] = [],
        childOrder: [NodeID] = [],
        name: String
    ) {
        self.id = id
        self.label = label
        self.position = .zero  // Enforce position at origin
        self.velocity = .zero  // Enforce no movement
        self.radius = radius
        self.isExpanded = isExpanded
        self.isCollapsible = isCollapsible
        self.children = children
        self.childOrder = childOrder
        self.name = name
    }
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        // IMMOVABLE: Always return self with position at origin
        var copy = self
        copy.position = .zero
        copy.velocity = .zero
        return copy
    }
    
    public func collapsed() -> Self {
        // Cannot collapse
        return self
    }
    
    public func bulkCollapsed() -> Self {
        // Cannot collapse
        return self
    }
}

// MARK: - Codable Conformance
@available(iOS 16.0, watchOS 9.0, *)
extension RootNode: Codable {
    enum CodingKeys: String, CodingKey {
        case id, label, position, velocity, radius
        case isExpanded, isCollapsible, children, childOrder
        case name
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        // Decode position but enforce origin
        _ = try container.decode(CGPoint.self, forKey: .position)
        position = .zero
        // Decode velocity but enforce zero
        _ = try container.decode(CGPoint.self, forKey: .velocity)
        velocity = .zero
        radius = try container.decode(CGFloat.self, forKey: .radius)
        isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        isCollapsible = try container.decode(Bool.self, forKey: .isCollapsible)
        children = try container.decode([NodeID].self, forKey: .children)
        childOrder = try container.decode([NodeID].self, forKey: .childOrder)
        name = try container.decode(String.self, forKey: .name)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(CGPoint.zero, forKey: .position)  // Always encode origin
        try container.encode(CGPoint.zero, forKey: .velocity)  // Always encode zero
        try container.encode(radius, forKey: .radius)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)
        try container.encode(name, forKey: .name)
    }
}
