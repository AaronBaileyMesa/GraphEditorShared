//
//  TacoNode.swift
//  GraphEditorShared
//
//  Represents a taco night planning node with meal workflow
//

import SwiftUI
import Foundation

/// Represents a single taco with protein, shell, and topping selections
@available(iOS 16.0, watchOS 9.0, *)
public struct TacoNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]
    public var childOrder: [NodeID]
    
    // Taco configuration properties
    public var protein: ProteinType?
    public var shell: ShellType?
    public var toppings: [String]

    public var displayRadius: CGFloat {
        radius * 1.3
    }

    public var fillColor: Color {
        .orange  // Taco-themed color
    }

    public var contents: [NodeContent] {
        get {
            [.string("🌮")]
        }
        set {
            _ = newValue  // Contents are read-only for TacoNode
        }
    }

    // MARK: - Initializers

    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = Constants.App.nodeModelRadius,
        protein: ProteinType? = .beef,
        shell: ShellType? = .softFlour,
        toppings: [String] = []
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = true
        self.isCollapsible = true
        self.children = []
        self.childOrder = []
        self.protein = protein
        self.shell = shell
        self.toppings = toppings
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
    
    public func with(protein: ProteinType?) -> Self {
        var updated = self
        updated.protein = protein
        return updated
    }
    
    public func with(shell: ShellType?) -> Self {
        var updated = self
        updated.shell = shell
        return updated
    }
    
    public func with(toppings: [String]) -> Self {
        var updated = self
        updated.toppings = toppings
        return updated
    }

    // MARK: - Ingredient Lookup

    /// Returns ingredients for this taco based on protein, shell, and toppings.
    /// Quantities are per single taco; callers should scale by total taco count.
    public func ingredientsForTaco() -> [(name: String, quantity: Decimal, unit: String)] {
        var ingredients: [(name: String, quantity: Decimal, unit: String)] = []

        // Protein
        switch protein {
        case .beef:
            ingredients.append(("Ground Beef", 0.25, "lb"))
        case .chicken:
            ingredients.append(("Chicken", 0.25, "lb"))
        case .none:
            break
        }

        // Shell
        switch shell {
        case .crunchy:
            ingredients.append(("Crunchy Taco Shells", 2, "count"))
        case .softFlour:
            ingredients.append(("Flour Tortillas", 2, "count"))
        case .softCorn:
            ingredients.append(("Corn Tortillas", 2, "count"))
        case .none:
            break
        }

        // Toppings
        let toppingIngredients: [String: (Decimal, String)] = [
            "Lettuce":            (0.25, "cup"),
            "Tomatoes":           (0.25, "cup"),
            "Cheese":             (0.125, "cup"),
            "Sour Cream":         (1, "tbsp"),
            "Guacamole":          (2, "tbsp"),
            "Salsa":              (2, "tbsp"),
            "Onions":             (2, "tbsp"),
            "Cilantro":           (1, "tbsp"),
            "Jalapeños":          (1, "tbsp"),
            "Hot Sauce":          (1, "tsp"),
            "Radishes":           (2, "count"),
            "Lime":               (0.25, "count"),
            "Pickled Jalapeños":  (1, "tbsp")
        ]

        for topping in toppings {
            if let (qty, unit) = toppingIngredients[topping] {
                ingredients.append((topping, qty, unit))
            }
        }

        return ingredients
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

    // MARK: - Type Descriptor

    public var typeDescriptor: NodeTypeDescriptor {
        TacoNodeDescriptor(node: self)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, radius
        case isExpanded, isCollapsible, children, childOrder
        case protein, shell, toppings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? Constants.App.nodeModelRadius

        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)

        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        isCollapsible = try container.decodeIfPresent(Bool.self, forKey: .isCollapsible) ?? true
        children = try container.decodeIfPresent([NodeID].self, forKey: .children) ?? []
        childOrder = try container.decodeIfPresent([NodeID].self, forKey: .childOrder) ?? []
        
        protein = try container.decodeIfPresent(ProteinType.self, forKey: .protein)
        shell = try container.decodeIfPresent(ShellType.self, forKey: .shell)
        toppings = try container.decodeIfPresent([String].self, forKey: .toppings) ?? []

        self.velocity = .zero
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(radius, forKey: .radius)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)
        try container.encodeIfPresent(protein, forKey: .protein)
        try container.encodeIfPresent(shell, forKey: .shell)
        try container.encode(toppings, forKey: .toppings)
    }
}

// MARK: - Equatable
@available(iOS 16.0, watchOS 9.0, *)
extension TacoNode {
    public static func == (lhs: TacoNode, rhs: TacoNode) -> Bool {
        lhs.id == rhs.id
    }
}
