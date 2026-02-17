//
//  PreferenceNode.swift
//  GraphEditorShared
//
//  Artifact node storing decisions collected from a decision tree
//

import SwiftUI
import Foundation

/// Stores preferences collected from decision tree, configures meal workflow
@available(iOS 16.0, watchOS 9.0, *)
public struct PreferenceNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]
    public var childOrder: [NodeID]
    
    // Core typed properties
    public let name: String  // "Taco Night Config"
    public let guestCount: Int
    public let dinnerTime: Date
    public let createdAt: Date
    public let mealNodeID: NodeID?  // Links to meal
    public let baseRecipeID: NodeID?  // Template recipe used
    public let clonedRecipeID: NodeID?  // Meal-specific instance
    
    // Flexible preferences dictionary
    public let preferences: [String: PreferenceValue]
    
    public var displayRadius: CGFloat {
        radius * 1.2
    }
    
    public var fillColor: Color {
        .purple
    }
    
    /// Human-readable summary of all preferences
    public var summary: String {
        var lines: [String] = []
        lines.append("Guests: \(guestCount)")
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        lines.append("Time: \(formatter.string(from: dinnerTime))")
        
        for (key, value) in preferences.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key.capitalized): \(value.displayString)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    public var contents: [NodeContent] {
        get {
            [
                .string(name),
                .string("\(guestCount) guests")
            ]
        }
        set {
            _ = newValue  // Contents are read-only
        }
    }
    
    // MARK: - Initializers
    
    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = 28.0,
        name: String,
        guestCount: Int,
        dinnerTime: Date,
        createdAt: Date = Date(),
        mealNodeID: NodeID? = nil,
        baseRecipeID: NodeID? = nil,
        clonedRecipeID: NodeID? = nil,
        preferences: [String: PreferenceValue] = [:]
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = true
        self.isCollapsible = false
        self.children = []
        self.childOrder = []
        self.name = name
        self.guestCount = guestCount
        self.dinnerTime = dinnerTime
        self.createdAt = createdAt
        self.mealNodeID = mealNodeID
        self.baseRecipeID = baseRecipeID
        self.clonedRecipeID = clonedRecipeID
        self.preferences = preferences
    }
    
    // MARK: - NodeProtocol Methods
    
    public func with(position: CGPoint, velocity: CGPoint) -> PreferenceNode {
        PreferenceNode(
            id: id,
            label: label,
            position: position,
            velocity: velocity,
            radius: radius,
            name: name,
            guestCount: guestCount,
            dinnerTime: dinnerTime,
            createdAt: createdAt,
            mealNodeID: mealNodeID,
            baseRecipeID: baseRecipeID,
            clonedRecipeID: clonedRecipeID,
            preferences: preferences
        )
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> PreferenceNode {
        with(position: position, velocity: velocity)
    }
    
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(
            Circle()
                .fill(fillColor)
                .frame(width: displayRadius * 2 * zoomScale, height: displayRadius * 2 * zoomScale)
                .overlay(
                    Text("\(label)")
                        .font(.system(size: 12 * zoomScale))
                        .foregroundColor(.white)
                )
        )
    }
    
    public func handlingTap() -> PreferenceNode {
        self
    }
    
    public func shouldHideChildren() -> Bool {
        false
    }
    
    public mutating func collapse() {
        // PreferenceNode doesn't collapse
    }
    
    public mutating func bulkCollapse() {
        // PreferenceNode doesn't collapse
    }

    public var typeDescriptor: NodeTypeDescriptor {
        PreferenceNodeDescriptor(node: self)
    }

    public var mass: CGFloat {
        15.0
    }
    
    public var isVisible: Bool {
        true
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius
        case isExpanded, isCollapsible, children, childOrder
        case name, guestCount, dinnerTime, createdAt
        case mealNodeID, baseRecipeID, clonedRecipeID, preferences
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        
        // swiftlint:disable:next identifier_name
        let x = try container.decode(CGFloat.self, forKey: .positionX)
        // swiftlint:disable:next identifier_name
        let y = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: x, y: y)

        // swiftlint:disable:next identifier_name
        let vx = try container.decode(CGFloat.self, forKey: .velocityX)
        // swiftlint:disable:next identifier_name
        let vy = try container.decode(CGFloat.self, forKey: .velocityY)
        velocity = CGPoint(x: vx, y: vy)
        
        radius = try container.decode(CGFloat.self, forKey: .radius)
        isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        isCollapsible = try container.decode(Bool.self, forKey: .isCollapsible)
        children = try container.decode([NodeID].self, forKey: .children)
        childOrder = try container.decode([NodeID].self, forKey: .childOrder)
        
        name = try container.decode(String.self, forKey: .name)
        guestCount = try container.decode(Int.self, forKey: .guestCount)
        dinnerTime = try container.decode(Date.self, forKey: .dinnerTime)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        mealNodeID = try container.decodeIfPresent(NodeID.self, forKey: .mealNodeID)
        baseRecipeID = try container.decodeIfPresent(NodeID.self, forKey: .baseRecipeID)
        clonedRecipeID = try container.decodeIfPresent(NodeID.self, forKey: .clonedRecipeID)
        preferences = try container.decode([String: PreferenceValue].self, forKey: .preferences)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
        try container.encode(radius, forKey: .radius)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)
        
        try container.encode(name, forKey: .name)
        try container.encode(guestCount, forKey: .guestCount)
        try container.encode(dinnerTime, forKey: .dinnerTime)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(mealNodeID, forKey: .mealNodeID)
        try container.encodeIfPresent(baseRecipeID, forKey: .baseRecipeID)
        try container.encodeIfPresent(clonedRecipeID, forKey: .clonedRecipeID)
        try container.encode(preferences, forKey: .preferences)
    }
}
