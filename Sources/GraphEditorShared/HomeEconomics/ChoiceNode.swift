//
//  ChoiceNode.swift
//  GraphEditorShared
//
//  Represents a selectable choice within a DecisionNode
//

import SwiftUI
import Foundation

/// Represents a selectable choice in a decision tree
@available(iOS 16.0, watchOS 9.0, *)
public struct ChoiceNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Choices don't have children
    public var childOrder: [NodeID]
    
    // Choice-specific properties
    public let choiceText: String  // "Beef", "Chicken", "Mild"
    public let value: PreferenceValue  // What gets stored if selected
    public var isSelected: Bool
    
    public var displayRadius: CGFloat {
        radius
    }
    
    public var fillColor: Color {
        isSelected ? .green : .gray
    }
    
    public var contents: [NodeContent] {
        get {
            [.string(choiceText)]
        }
        set {
            _ = newValue  // Read-only
        }
    }
    
    // MARK: - Initializers
    
    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = 12.0,
        choiceText: String,
        value: PreferenceValue,
        isSelected: Bool = false
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
        self.choiceText = choiceText
        self.value = value
        self.isSelected = isSelected
    }
    
    // MARK: - NodeProtocol Methods
    
    public func with(position: CGPoint, velocity: CGPoint) -> ChoiceNode {
        ChoiceNode(
            id: id,
            label: label,
            position: position,
            velocity: velocity,
            radius: radius,
            choiceText: choiceText,
            value: value,
            isSelected: isSelected
        )
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> ChoiceNode {
        with(position: position, velocity: velocity)
    }
    
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(
            Circle()
                .fill(fillColor)
                .frame(width: displayRadius * 2 * zoomScale, height: displayRadius * 2 * zoomScale)
                .overlay(
                    Text("\(label)")
                        .font(.system(size: 10 * zoomScale))
                        .foregroundColor(.white)
                )
        )
    }
    
    public func handlingTap() -> ChoiceNode {
        var updated = self
        updated.isSelected.toggle()
        return updated
    }
    
    public func shouldHideChildren() -> Bool {
        false
    }
    
    public mutating func collapse() {
        // ChoiceNode doesn't collapse
    }
    
    public mutating func bulkCollapse() {
        // ChoiceNode doesn't collapse
    }

    public var typeDescriptor: NodeTypeDescriptor {
        ChoiceNodeDescriptor(node: self)
    }

    public var mass: CGFloat {
        8.0
    }
    
    public var isVisible: Bool {
        true
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius
        case isExpanded, isCollapsible, children, childOrder
        case choiceText, value, isSelected
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
        
        choiceText = try container.decode(String.self, forKey: .choiceText)
        value = try container.decode(PreferenceValue.self, forKey: .value)
        isSelected = try container.decode(Bool.self, forKey: .isSelected)
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
        
        try container.encode(choiceText, forKey: .choiceText)
        try container.encode(value, forKey: .value)
        try container.encode(isSelected, forKey: .isSelected)
    }
}
