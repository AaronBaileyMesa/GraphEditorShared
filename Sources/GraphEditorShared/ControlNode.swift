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
    
    // MARK: Init – supports both global and per-node controls
    public init(
        position: CGPoint,
        ownerID: NodeID?,
        kind: ControlKind,
        isVisible: Bool = true,
        priority: Int = 0,
        action: (() -> Void)? = nil,
        relativeAngle: CGFloat = 0.0
    ) {
        self.position = position
        self.ownerID = ownerID
        self.kind = kind
        self.isVisible = isVisible
        self.priority = priority
        self.action = action
        self.relativeAngle = relativeAngle
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
    
    @available(iOS 15.0, watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        let iconName: String = switch kind {

        case .addChild:         "plus.circle.fill"
        case .addEdge:          "arrow.right.circle.fill"
        case .edit:             "pencil"
        case .delete:           "trash.fill"
        case .duplicate:        "doc.on.doc.fill"
        case .addToggleChild:   "checklist"
        }

        return AnyView(
            ZStack {
                Circle()
                    .fill(fillColor.opacity(0.9))
                    .frame(width: radius * 2 * zoomScale, height: radius * 2 * zoomScale)

                Image(systemName: iconName)
                    .font(.system(size: 16 * zoomScale, weight: .medium))
                    .foregroundColor(.white)
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
        lhs.relativeAngle == rhs.relativeAngle  // NEW
    }
}

// MARK: - Codable (optional – only if you ever persist controls, which you don’t)
extension ControlNode: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, position, velocity, radius, ownerID, kind, isVisible, priority, relativeAngle
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
    }
}
