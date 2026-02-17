//
//  MealNode.swift
//  GraphEditorShared
//
//  Represents a scheduled meal with date and participants
//

import SwiftUI
import Foundation

/// Represents a scheduled meal (e.g., "Monday Dinner: Pasta")
@available(iOS 16.0, watchOS 9.0, *)
public struct MealNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Related tasks (shop, prep, cook)
    public var childOrder: [NodeID]

    // Meal-specific properties
    public let name: String
    public let date: Date
    public let mealType: MealType
    public let servings: Int
    public let recipeID: NodeID?  // Optional linked recipe

    // Taco dinner workflow properties
    public let guests: Int
    public let dinnerTime: Date
    public let protein: ProteinType?

    public var displayRadius: CGFloat {
        radius * 1.3  // Slightly larger for meals
    }

    public var fillColor: Color {
        switch mealType {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .purple
        case .snack: return .pink
        }
    }

    public var contents: [NodeContent] {
        get {
            [
                .string(name),
                .date(date)
            ]
        }
        set {
            _ = newValue  // Contents are read-only for MealNode
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
        date: Date,
        mealType: MealType,
        servings: Int,
        recipeID: NodeID? = nil,
        guests: Int? = nil,
        dinnerTime: Date? = nil,
        protein: ProteinType? = nil
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.name = name
        self.date = date
        self.mealType = mealType
        self.servings = servings
        self.recipeID = recipeID
        self.guests = guests ?? servings  // Default to servings if not specified
        self.dinnerTime = dinnerTime ?? date  // Default to meal date if not specified
        self.protein = protein
        self.isExpanded = true
        self.isCollapsible = true  // Can collapse to hide tasks
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
        // Note: name and date are immutable
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

    // MARK: - Type Descriptor

    public var typeDescriptor: NodeTypeDescriptor {
        MealNodeDescriptor(node: self)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, radius
        case name, date, mealType, servings, recipeID
        case guests, dinnerTime, protein
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
        date = try container.decode(Date.self, forKey: .date)
        mealType = try container.decode(MealType.self, forKey: .mealType)
        servings = try container.decode(Int.self, forKey: .servings)
        recipeID = try container.decodeIfPresent(NodeID.self, forKey: .recipeID)

        // Decode new properties with backward compatibility
        let decodedGuests = try container.decodeIfPresent(Int.self, forKey: .guests)
        guests = decodedGuests ?? servings

        let decodedDinnerTime = try container.decodeIfPresent(Date.self, forKey: .dinnerTime)
        dinnerTime = decodedDinnerTime ?? date

        protein = try container.decodeIfPresent(ProteinType.self, forKey: .protein)

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
        try container.encode(date, forKey: .date)
        try container.encode(mealType, forKey: .mealType)
        try container.encode(servings, forKey: .servings)
        try container.encodeIfPresent(recipeID, forKey: .recipeID)
        try container.encode(guests, forKey: .guests)
        try container.encode(dinnerTime, forKey: .dinnerTime)
        try container.encodeIfPresent(protein, forKey: .protein)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)
    }
}

// MARK: - Equatable
@available(iOS 16.0, watchOS 9.0, *)
extension MealNode {
    public static func == (lhs: MealNode, rhs: MealNode) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.date == rhs.date
    }
}
