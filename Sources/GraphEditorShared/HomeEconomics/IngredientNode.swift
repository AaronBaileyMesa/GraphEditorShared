//
//  IngredientNode.swift
//  GraphEditorShared
//
//  Represents an ingredient with quantity and measurement unit
//

import SwiftUI
import Foundation

/// Represents an ingredient (e.g., "2 cups flour", "4 eggs")
@available(iOS 16.0, watchOS 9.0, *)
public struct IngredientNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Always empty for ingredients
    public var childOrder: [NodeID]

    // Ingredient-specific properties
    public let name: String
    public let quantity: Decimal
    public let unit: MeasurementUnit

    public var displayRadius: CGFloat {
        radius * 0.9  // Smaller for ingredients
    }

    public var fillColor: Color {
        .green
    }

    public var contents: [NodeContent] {
        get {
            [
                .string(name),
                .number(Double(truncating: quantity as NSNumber)),
                .string(unit.abbreviation)
            ]
        }
        set {
            _ = newValue  // Contents are read-only for IngredientNode
        }
    }

    /// Display string like "4 eggs" or "2 cups flour"
    public var displayString: String {
        let qtyStr: String
        if quantity == 1 && unit == .whole {
            qtyStr = ""
        } else {
            qtyStr = "\(quantity) "
        }

        let unitStr = unit.abbreviation.isEmpty ? "" : "\(unit.abbreviation) "
        return "\(qtyStr)\(unitStr)\(name)"
    }

    // MARK: - Initializers

    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = Constants.App.nodeModelRadius,
        name: String,
        quantity: Decimal,
        unit: MeasurementUnit
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.isExpanded = true
        self.isCollapsible = false  // Ingredients don't collapse
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
        // Note: name, quantity, and unit are immutable
        return updated
    }

    public func with(children: [NodeID]) -> Self {
        // Ingredients don't have children
        return self
    }

    public func with(childOrder: [NodeID]) -> Self {
        // Ingredients don't have children
        return self
    }

    public func with(isExpanded: Bool) -> Self {
        // Ingredients are not collapsible
        return self
    }

    public func shouldHideChildren() -> Bool {
        false  // No children to hide
    }

    public func handlingTap() -> Self {
        // No tap behavior for ingredients
        return self
    }

    public mutating func collapse() {
        // No collapse behavior
    }

    public mutating func bulkCollapse() {
        // No collapse behavior
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, radius
        case name, quantity, unit
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

        // Decode Decimal as string (standard approach)
        let quantityString = try container.decode(String.self, forKey: .quantity)
        quantity = Decimal(string: quantityString) ?? 0

        unit = try container.decode(MeasurementUnit.self, forKey: .unit)

        self.velocity = .zero
        self.isExpanded = true
        self.isCollapsible = false
        self.children = []
        self.childOrder = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(radius, forKey: .radius)
        try container.encode(name, forKey: .name)
        try container.encode(quantity.description, forKey: .quantity)  // Encode Decimal as string
        try container.encode(unit, forKey: .unit)
    }
}

// MARK: - Equatable
@available(iOS 16.0, watchOS 9.0, *)
extension IngredientNode {
    public static func == (lhs: IngredientNode, rhs: IngredientNode) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.quantity == rhs.quantity
    }
}
