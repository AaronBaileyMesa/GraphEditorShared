//
//  PersonNode.swift
//  GraphEditorShared
//
//  Represents a person (household member or guest) with food preferences
//

import SwiftUI
import Foundation

/// Represents a person with dietary preferences and restrictions
@available(iOS 16.0, watchOS 9.0, *)
public struct PersonNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Potentially linked to meals they participate in
    public var childOrder: [NodeID]
    
    // Person-specific properties
    public let name: String
    public let defaultSpiceLevel: String?  // "mild", "medium", "hot"
    public let dietaryRestrictions: [String]  // ["vegetarian", "gluten-free", etc.]
    
    public var displayRadius: CGFloat {
        radius
    }
    
    public var fillColor: Color {
        .blue
    }
    
    public var contents: [NodeContent] {
        get {
            var result: [NodeContent] = [.string(name)]
            if let spice = defaultSpiceLevel {
                result.append(.string("Spice: \(spice)"))
            }
            if !dietaryRestrictions.isEmpty {
                result.append(.string(dietaryRestrictions.joined(separator: ", ")))
            }
            return result
        }
        set {
            _ = newValue  // Contents are read-only for PersonNode
        }
    }
    
    // MARK: - Initializers
    
    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = 12.0,  // 24" diameter (1pt = 1 inch scale)
        name: String,
        defaultSpiceLevel: String? = nil,
        dietaryRestrictions: [String] = []
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = false
        self.isCollapsible = false
        self.children = []
        self.childOrder = []
        self.name = name
        self.defaultSpiceLevel = defaultSpiceLevel
        self.dietaryRestrictions = dietaryRestrictions
    }
    
    // MARK: - NodeProtocol Methods
    
    public func with(position: CGPoint, velocity: CGPoint) -> PersonNode {
        PersonNode(
            id: id,
            label: label,
            position: position,
            velocity: velocity,
            radius: radius,
            name: name,
            defaultSpiceLevel: defaultSpiceLevel,
            dietaryRestrictions: dietaryRestrictions
        )
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> PersonNode {
        // PersonNode doesn't support modifying via contents
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
    
    public func handlingTap() -> PersonNode {
        self
    }
    
    public func shouldHideChildren() -> Bool {
        false
    }
    
    public mutating func collapse() {
        // PersonNode doesn't collapse
    }
    
    public mutating func bulkCollapse() {
        // PersonNode doesn't collapse
    }
    
    public var mass: CGFloat {
        10.0
    }
    
    public var isVisible: Bool {
        true
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius
        case isExpanded, isCollapsible, children, childOrder
        case name, defaultSpiceLevel, dietaryRestrictions
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
        
        let vx = try container.decode(CGFloat.self, forKey: .velocityX)
        let vy = try container.decode(CGFloat.self, forKey: .velocityY)
        velocity = CGPoint(x: vx, y: vy)
        
        radius = try container.decode(CGFloat.self, forKey: .radius)
        isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        isCollapsible = try container.decode(Bool.self, forKey: .isCollapsible)
        children = try container.decode([NodeID].self, forKey: .children)
        childOrder = try container.decode([NodeID].self, forKey: .childOrder)
        
        name = try container.decode(String.self, forKey: .name)
        defaultSpiceLevel = try container.decodeIfPresent(String.self, forKey: .defaultSpiceLevel)
        dietaryRestrictions = try container.decode([String].self, forKey: .dietaryRestrictions)
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
        try container.encodeIfPresent(defaultSpiceLevel, forKey: .defaultSpiceLevel)
        try container.encode(dietaryRestrictions, forKey: .dietaryRestrictions)
    }
}
