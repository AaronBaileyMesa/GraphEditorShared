//
//  PeopleListNode.swift
//  GraphEditorShared
//
//  Container node for organizing PersonNodes
//

import SwiftUI
import Foundation

/// Container node that groups all PersonNodes in the graph
@available(iOS 16.0, watchOS 9.0, *)
public struct PeopleListNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // PersonNode IDs
    public var childOrder: [NodeID]

    // PeopleListNode-specific properties
    public let name: String

    public var displayRadius: CGFloat {
        radius * 1.5  // Larger for list container
    }

    public var fillColor: Color {
        .blue.opacity(0.8)
    }

    public var contents: [NodeContent] {
        get {
            let count = children.count
            let countText = count == 1 ? "1 person" : "\(count) people"
            return [.string(name), .string(countText)]
        }
        set {
            _ = newValue  // Contents are read-only for PeopleListNode
        }
    }

    // MARK: - Initializers

    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = Constants.App.nodeModelRadius,
        name: String = "People",
        isExpanded: Bool = true,
        isCollapsible: Bool = true
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.name = name
        self.isExpanded = isExpanded
        self.isCollapsible = isCollapsible
        self.children = []
        self.childOrder = []
    }

    // MARK: - NodeProtocol Requirements

    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        var updated = self
        updated.position = position
        updated.velocity = velocity
        return updated
    }

    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        var updated = self
        updated.position = position
        updated.velocity = velocity
        // Note: name is immutable, so contents update ignored
        return updated
    }

    public func with(children: [NodeID]) -> Self {
        var updated = self
        updated.children = children
        return updated
    }

    public func with(childOrder: [NodeID]) -> Self {
        var updated = self
        updated.childOrder = childOrder
        return updated
    }

    public func with(isExpanded: Bool) -> Self {
        var updated = self
        updated.isExpanded = isExpanded
        return updated
    }

    public func shouldHideChildren() -> Bool {
        isCollapsible && !isExpanded
    }

    public func handlingTap() -> Self {
        guard isCollapsible else { return self }
        var updated = self
        updated.isExpanded.toggle()
        updated.velocity = .zero
        return updated
    }

    public mutating func collapse() {
        isExpanded = false
    }

    public mutating func bulkCollapse() {
        isExpanded = false
    }

    public var typeDescriptor: NodeTypeDescriptor {
        PeopleListNodeDescriptor(node: self)
    }

    public var mass: CGFloat {
        3.0  // Heavier than individual person nodes
    }

    public var isVisible: Bool {
        true
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius
        case name
        case isExpanded, isCollapsible, children, childOrder
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
        let vx = try container.decodeIfPresent(CGFloat.self, forKey: .velocityX) ?? 0
        // swiftlint:disable:next identifier_name
        let vy = try container.decodeIfPresent(CGFloat.self, forKey: .velocityY) ?? 0
        velocity = CGPoint(x: vx, y: vy)
        
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? Constants.App.nodeModelRadius
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "People"
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        isCollapsible = try container.decodeIfPresent(Bool.self, forKey: .isCollapsible) ?? true
        children = try container.decodeIfPresent([NodeID].self, forKey: .children) ?? []
        childOrder = try container.decodeIfPresent([NodeID].self, forKey: .childOrder) ?? []
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
        try container.encode(name, forKey: .name)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)
    }
}

// MARK: - Equatable
@available(iOS 16.0, watchOS 9.0, *)
extension PeopleListNode {
    public static func == (lhs: PeopleListNode, rhs: PeopleListNode) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
