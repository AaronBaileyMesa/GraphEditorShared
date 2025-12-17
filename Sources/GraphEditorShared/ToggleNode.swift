//
//  ToggleNode.swift
//  GraphEditorShared
//
//  Created by handcart on [date]; updated for completeness.
//

import SwiftUI
import Foundation
import os

@available(iOS 16.0, *)
@available(watchOS 9.0, *)
public struct ToggleNode: NodeProtocol, Equatable {  // Updated: Added HierarchicalNode
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = Constants.App.nodeModelRadius  // Use constant for consistency
    public var isExpanded: Bool = true
    public var contents: [NodeContent] = []  // NEW: Ordered list, default empty
    public var fillColor: Color { isExpanded ? .green : .red }
    public var children: [NodeID] = []
    public var childOrder: [NodeID] = []  // NEW: Explicit order for children (defaults to children array order)
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "togglenode")
    
    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero, radius: CGFloat = Constants.App.nodeModelRadius, isExpanded: Bool = true, contents: [NodeContent] = [], children: [NodeID] = [], childOrder: [NodeID]? = nil) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = isExpanded
        self.contents = contents
        self.children = children
        // Validate childOrder to be a permutation of children
        let validatedOrder = (childOrder ?? children).filter { children.contains($0) }
        self.childOrder = validatedOrder.isEmpty ? children : validatedOrder
        ToggleNode.logger.debug("ToggleNode created – isExpanded: \(isExpanded)")
    }
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents, children: children, childOrder: childOrder)
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents, children: children, childOrder: childOrder)
    }
    
    public func handlingTap() -> Self {
        var updated = self
        print("ToggleNode.handlingTap: Pre-collapse - current isExpanded: \(updated.isExpanded)")
        updated.isExpanded = !updated.isExpanded  // Toggle here
        print("ToggleNode.handlingTap: Post-collapse - updated isExpanded: \(updated.isExpanded)")  // Will always show false
        updated.velocity = .zero
        return updated
    }
    
    public mutating func collapse() {
        print("ToggleNode.collapse: Setting isExpanded to false from \(isExpanded)")
        isExpanded = false
    }
    
    public func with(children: [NodeID]) -> Self {
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents, children: children, childOrder: childOrder)
    }
    
    public func with(childOrder: [NodeID]) -> Self {  // NEW: Method to update order independently
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents, children: children, childOrder: childOrder)
    }
    
    public func with(isExpanded: Bool) -> Self {
        print("ToggleNode.with(isExpanded): Input \(isExpanded), self \(self.isExpanded)")  // Trace input vs self
        return ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents, children: children, childOrder: childOrder)
    }
    
    public func shouldHideChildren() -> Bool {
        print("ToggleNode.shouldHideChildren for label \(label) (ID: \(id.uuidString.prefix(8))): isExpanded = \(isExpanded), result = \(!isExpanded)")
        return !isExpanded
    }
    
    @available(iOS 16.0, *)
    @available(watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(Circle().fill(fillColor).frame(width: radius * 2 * zoomScale, height: radius * 2 * zoomScale))  // Simple default
    }
  
    public mutating func bulkCollapse() {
        isExpanded = false
        // Recursion handled in GraphModel for full graph access
    }
    
    // Codable conformance (updated for contents array and childOrder)
    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius, isExpanded, contents, children, childOrder  // UPDATED: Added children and childOrder
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? Constants.App.nodeModelRadius  // Default if missing
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true  // Default if missing
        contents = try container.decodeIfPresent([NodeContent].self, forKey: .contents) ?? []  // Default if missing
        children = try container.decodeIfPresent([NodeID].self, forKey: .children) ?? []  // Default if missing
        childOrder = try container.decodeIfPresent([NodeID].self, forKey: .childOrder) ?? []  // NEW: Decode childOrder (optional fallback to empty)
        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)
        self.velocity = .zero  // instead of decoding whatever garbage was saved
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(radius, forKey: .radius)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(contents, forKey: .contents)  // NEW: Encode array
        try container.encode(children, forKey: .children)  // NEW: Encode children
        try container.encode(childOrder, forKey: .childOrder)  // NEW: Encode childOrder
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
    }
    
    public static func == (lhs: ToggleNode, rhs: ToggleNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.label == rhs.label &&
        lhs.position == rhs.position &&
        lhs.velocity == rhs.velocity &&
        lhs.radius == rhs.radius &&
        lhs.isExpanded == rhs.isExpanded &&
        lhs.contents == rhs.contents &&
        lhs.children == rhs.children &&  // UPDATED: Include children
        lhs.childOrder == rhs.childOrder  // UPDATED: Include childOrder
    }
    
}

extension ToggleNode {
    mutating func toggleExpansion() {
        isExpanded.toggle()
    }
}
