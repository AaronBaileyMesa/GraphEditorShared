//
//  RecipeNode.swift
//  GraphEditorShared
//
//  Represents a recipe with instructions and timing information
//

import SwiftUI
import Foundation

/// Represents a recipe (e.g., "Spaghetti Carbonara")
@available(iOS 16.0, watchOS 9.0, *)
public struct RecipeNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Ingredient nodes
    public var childOrder: [NodeID]

    // Recipe-specific properties
    public let name: String
    public let instructions: String
    public let prepTime: Int        // minutes
    public let cookTime: Int        // minutes
    public let servings: Int
    public let difficulty: String   // "easy", "medium", "hard"

    public var displayRadius: CGFloat {
        radius * 1.4
    }

    public var fillColor: Color {
        .cyan
    }

    public var contents: [NodeContent] {
        get {
            [
                .string(name),
                .number(Double(prepTime + cookTime))  // total time
            ]
        }
        set {
            _ = newValue  // Contents are read-only for RecipeNode
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
        instructions: String,
        prepTime: Int,
        cookTime: Int,
        servings: Int,
        difficulty: String = "medium"
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.name = name
        self.instructions = instructions
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.difficulty = difficulty
        self.isExpanded = true
        self.isCollapsible = true  // Can collapse to hide ingredients
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
        // Note: name and instructions are immutable
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
        RecipeNodeDescriptor(node: self)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, radius
        case name, instructions, prepTime, cookTime, servings, difficulty
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
        instructions = try container.decode(String.self, forKey: .instructions)
        prepTime = try container.decode(Int.self, forKey: .prepTime)
        cookTime = try container.decode(Int.self, forKey: .cookTime)
        servings = try container.decode(Int.self, forKey: .servings)
        difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty) ?? "medium"

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
        try container.encode(instructions, forKey: .instructions)
        try container.encode(prepTime, forKey: .prepTime)
        try container.encode(cookTime, forKey: .cookTime)
        try container.encode(servings, forKey: .servings)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)
    }
}

// MARK: - Equatable
@available(iOS 16.0, watchOS 9.0, *)
extension RecipeNode {
    public static func == (lhs: RecipeNode, rhs: RecipeNode) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
