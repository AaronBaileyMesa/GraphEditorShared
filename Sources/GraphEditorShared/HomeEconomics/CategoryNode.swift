//
//  CategoryNode.swift
//  GraphEditorShared
//
//  Represents a spending category (e.g., Groceries, Utilities)
//

import SwiftUI
import Foundation

/// Represents a spending category (e.g., Groceries, Utilities)
@available(iOS 16.0, watchOS 9.0, *)
public struct CategoryNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Transactions in this category
    public var childOrder: [NodeID]

    // Category-specific properties
    public let name: String
    public let color: Color
    public let icon: String  // SF Symbol name

    public var displayRadius: CGFloat {
        radius * 1.5  // Larger for categories
    }

    public var fillColor: Color {
        color
    }

    public var contents: [NodeContent] {
        get {
            [.string(name)]
        }
        set {
            _ = newValue  // Contents are read-only for CategoryNode
        }
    }

    // MARK: - Initializers

    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = Constants.App.nodeModelRadius,
        name: String,
        color: Color = .blue,
        icon: String = "tag.fill",
        isCollapsible: Bool = true
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.name = name
        self.color = color
        self.icon = icon
        self.isExpanded = true
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
        CategoryNodeDescriptor(node: self)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, radius
        case name, colorDescription, icon
        case isExpanded, isCollapsible, children, childOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? Constants.App.nodeModelRadius

        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)

        name = try container.decode(String.self, forKey: .name)
        let colorDesc = try container.decode(String.self, forKey: .colorDescription)
        // Simple color parsing - store as string and parse back
        color = Self.parseColor(from: colorDesc)
        icon = try container.decode(String.self, forKey: .icon)

        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        isCollapsible = try container.decodeIfPresent(Bool.self, forKey: .isCollapsible) ?? true
        children = try container.decodeIfPresent([NodeID].self, forKey: .children) ?? []
        childOrder = try container.decodeIfPresent([NodeID].self, forKey: .childOrder) ?? []

        self.velocity = .zero
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(radius, forKey: .radius)
        try container.encode(name, forKey: .name)
        try container.encode(Self.colorToString(color), forKey: .colorDescription)
        try container.encode(icon, forKey: .icon)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)
    }

    // Helper: Convert Color to string for serialization
    private static func colorToString(_ color: Color) -> String {
        // Simple mapping - extend as needed
        switch color {
        case .red: return "red"
        case .green: return "green"
        case .blue: return "blue"
        case .orange: return "orange"
        case .yellow: return "yellow"
        case .purple: return "purple"
        case .pink: return "pink"
        default: return "blue"
        }
    }

    // Helper: Parse Color from string
    private static func parseColor(from string: String) -> Color {
        switch string.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        case "pink": return .pink
        default: return .blue
        }
    }
}

// MARK: - Equatable
@available(iOS 16.0, watchOS 9.0, *)
extension CategoryNode {
    public static func == (lhs: CategoryNode, rhs: CategoryNode) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
