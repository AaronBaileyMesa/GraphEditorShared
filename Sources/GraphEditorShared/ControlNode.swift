//
//  ControlNode.swift
//  GraphEditorShared
//
//  Created by handcart on 2025-11-22
//

import SwiftUI

/// Ephemeral on-screen control that behaves exactly like a normal node
/// (physics, rendering, hit-testing) but is never persisted.
public struct ControlNode: NodeProtocol {
    
    // MARK: Hierarchical state required by NodeProtocol / AnyNode
    public var isExpanded: Bool = false
    public var children: [NodeID] = []
    public var childOrder: [NodeID] = []
    
    // MARK: Core NodeProtocol properties
    public private(set) var id: NodeID = NodeID()
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = Constants.App.nodeModelRadius * 0.85  // Increased from 0.75 for better touch targets
    public var contents: [NodeContent] = []
    
    // MARK: Display label (required by NodeProtocol)
    public var label: Int { 0 } // Controls have no numbered label
    public var relativeAngle: CGFloat = 0.0  // NEW: Stored angle (degrees) relative to owner, set at creation
    
    // MARK: Control-specific
    public let ownerID: NodeID?
    public let kind: ControlKind
    public var isVisible: Bool = true
    public var priority: Int = 0
    // Optional action closure
    public var action: (() -> Void)?
    // Owner node's expansion state (for toggleExpand icon rendering)
    public var ownerIsExpanded: Bool = true
    
    // MARK: Init – supports both global and per-node controls
    public init(
        position: CGPoint,
        ownerID: NodeID?,
        kind: ControlKind,
        isVisible: Bool = true,
        priority: Int = 0,
        action: (() -> Void)? = nil,
        relativeAngle: CGFloat = 0.0,
        ownerIsExpanded: Bool = true
    ) {
        self.position = position
        self.ownerID = ownerID
        self.kind = kind
        self.isVisible = isVisible
        self.priority = priority
        self.action = action
        self.relativeAngle = relativeAngle
        self.ownerIsExpanded = ownerIsExpanded
    }
    
    // MARK: Required NodeProtocol methods
    public var displayRadius: CGFloat { radius }
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        var copy = self
        copy.position = position
        copy.velocity = velocity
        return copy
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        var copy = self.with(position: position, velocity: velocity)
        copy.contents = contents
        return copy
    }
    
    public mutating func collapse() { }
    public mutating func bulkCollapse() { }

    public var typeDescriptor: NodeTypeDescriptor {
        ControlNodeDescriptor(node: self)
    }

    public func handlingTap() -> Self {
        action?()
        return self
    }
    
    public func shouldHideChildren() -> Bool { false }
    
    public var mass: CGFloat { 1.0 }
    
    /// Color based on control action type
    public var fillColor: Color {
        kind.color
    }
    
    /// Check if this control represents a selected option
    public func isSelected(in nodes: [AnyNode]) -> Bool {
        guard let ownerID = ownerID,
              let tacoNode = nodes.first(where: { $0.id == ownerID })?.unwrapped as? TacoNode else {
            return false
        }
        
        switch kind {
        case .toggleBeef:
            return tacoNode.protein == .beef
        case .toggleChicken:
            return tacoNode.protein == .chicken
        case .toggleCrunchyShell:
            return tacoNode.shell == .crunchy
        case .toggleSoftFlourShell:
            return tacoNode.shell == .softFlour
        case .toggleSoftCornShell:
            return tacoNode.shell == .softCorn
        case .toggleLettuce:
            return tacoNode.toppings.contains("Lettuce")
        case .toggleTomatoes:
            return tacoNode.toppings.contains("Tomatoes")
        case .toggleCheese:
            return tacoNode.toppings.contains("Cheese")
        case .toggleSourCream:
            return tacoNode.toppings.contains("Sour Cream")
        case .toggleGuacamole:
            return tacoNode.toppings.contains("Guacamole")
        case .toggleSalsa:
            return tacoNode.toppings.contains("Salsa")
        case .toggleOnions:
            return tacoNode.toppings.contains("Onions")
        case .toggleCilantro:
            return tacoNode.toppings.contains("Cilantro")
        case .toggleJalapeños:
            return tacoNode.toppings.contains("Jalapeños")
        case .toggleHotSauce:
            return tacoNode.toppings.contains("Hot Sauce")
        case .toggleRadishes:
            return tacoNode.toppings.contains("Radishes")
        case .toggleLime:
            return tacoNode.toppings.contains("Lime")
        case .togglePickledJalapeños:
            return tacoNode.toppings.contains("Pickled Jalapeños")
        default:
            return false
        }
    }
    
    @available(iOS 15.0, watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        return AnyView(
            ZStack {
                Circle()
                    .fill(fillColor.opacity(0.9))
                    .frame(width: radius * 2 * zoomScale, height: radius * 2 * zoomScale)

                if let textLabel = kind.textLabel {
                    // Show text label for controls that need it (taco options)
                    Text(textLabel)
                        .font(.system(size: 10 * zoomScale, weight: .bold))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                } else {
                    // Show icon for standard controls (with dynamic chevron for toggleExpand)
                    let iconName = kind.renderIcon(isExpanded: ownerIsExpanded)
                    #if DEBUG
                    let _ = {
                        if kind == .toggleExpand {
                            print("🔧 Rendering toggleExpand icon: '\(iconName)' with ownerIsExpanded=\(ownerIsExpanded)")
                        }
                    }()
                    #endif
                    Image(systemName: iconName)
                        .font(.system(size: 16 * zoomScale, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .opacity(isSelected ? 1.0 : 0.8)
        )
    }
}

// MARK: - Equatable
extension ControlNode: Equatable {
    public static func == (lhs: ControlNode, rhs: ControlNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.position == rhs.position &&
        lhs.velocity == rhs.velocity &&
        lhs.kind == rhs.kind &&
        lhs.ownerID == rhs.ownerID &&
        lhs.isVisible == rhs.isVisible &&
        lhs.relativeAngle == rhs.relativeAngle &&
        lhs.ownerIsExpanded == rhs.ownerIsExpanded
    }
}

// MARK: - Codable (optional – only if you ever persist controls, which you don’t)
extension ControlNode: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, position, velocity, radius, ownerID, kind, isVisible, priority, relativeAngle, ownerIsExpanded
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(NodeID.self, forKey: .id)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.velocity = try container.decode(CGPoint.self, forKey: .velocity)
        self.radius = try container.decode(CGFloat.self, forKey: .radius)
        self.ownerID = try container.decodeIfPresent(NodeID.self, forKey: .ownerID)
        self.kind = try container.decode(ControlKind.self, forKey: .kind)
        self.isVisible = try container.decode(Bool.self, forKey: .isVisible)
        self.priority = try container.decode(Int.self, forKey: .priority)
        self.relativeAngle = try container.decode(CGFloat.self, forKey: .relativeAngle)
        self.ownerIsExpanded = try container.decodeIfPresent(Bool.self, forKey: .ownerIsExpanded) ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(position, forKey: .position)
        try container.encode(velocity, forKey: .velocity)
        try container.encode(radius, forKey: .radius)
        try container.encode(ownerID, forKey: .ownerID)
        try container.encode(kind, forKey: .kind)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(priority, forKey: .priority)
        try container.encode(relativeAngle, forKey: .relativeAngle)
        try container.encode(ownerIsExpanded, forKey: .ownerIsExpanded)
    }
}
