//
//  TransactionNode.swift
//  GraphEditorShared
//
//  Represents a financial transaction (income or expense)
//

import SwiftUI
import Foundation

/// Represents a financial transaction (income or expense)
@available(iOS 16.0, watchOS 9.0, *)
public struct TransactionNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]
    public var childOrder: [NodeID]

    // Transaction-specific properties
    public let amount: Decimal
    public let transactionDate: Date
    public let transactionDescription: String
    public let transactionType: TransactionType
    public let categoryID: NodeID?
    public let payerID: NodeID?

    public var displayRadius: CGFloat {
        radius * 1.2  // Slightly larger for visibility
    }

    public var fillColor: Color {
        switch transactionType {
        case .income: return .green
        case .expense: return .red
        }
    }

    public var contents: [NodeContent] {
        get {
            [
                .number(Double(truncating: amount as NSNumber)),
                .date(transactionDate),
                .string(transactionDescription)
            ]
        }
        set {
            _ = newValue  // Contents are read-only for TransactionNode
        }
    }

    // MARK: - Initializers

    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = Constants.App.nodeModelRadius,
        amount: Decimal,
        transactionDate: Date,
        description: String,
        transactionType: TransactionType,
        categoryID: NodeID? = nil,
        payerID: NodeID? = nil
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.amount = amount
        self.transactionDate = transactionDate
        self.transactionDescription = description
        self.transactionType = transactionType
        self.categoryID = categoryID
        self.payerID = payerID
        self.isExpanded = true
        self.isCollapsible = false
        self.children = []
        self.childOrder = []
    }

    // MARK: - NodeProtocol Requirements

    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        TransactionNode(
            id: id, label: label, position: position, velocity: velocity,
            radius: radius, amount: amount, transactionDate: transactionDate,
            description: transactionDescription, transactionType: transactionType,
            categoryID: categoryID, payerID: payerID
        )
    }

    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        // Extract updated values from contents if present
        var updatedAmount = amount
        var updatedDate = transactionDate
        var updatedDesc = transactionDescription

        for content in contents {
            switch content {
            case .number(let value): updatedAmount = Decimal(value)
            case .date(let value): updatedDate = value
            case .string(let value): updatedDesc = value
            default: break
            }
        }

        return TransactionNode(
            id: id, label: label, position: position, velocity: velocity,
            radius: radius, amount: updatedAmount, transactionDate: updatedDate,
            description: updatedDesc, transactionType: transactionType,
            categoryID: categoryID, payerID: payerID
        )
    }

    public func with(children: [NodeID]) -> Self {
        self  // Transactions don't have children
    }

    public func with(childOrder: [NodeID]) -> Self {
        self  // Transactions don't have children
    }

    public func with(isExpanded: Bool) -> Self {
        self  // Not collapsible
    }

    public func shouldHideChildren() -> Bool {
        false  // No children
    }

    public func handlingTap() -> Self {
        self  // No tap behavior
    }

    public mutating func collapse() {
        // Transactions don't collapse
    }

    public mutating func bulkCollapse() {
        // Transactions don't collapse
    }

    public var typeDescriptor: NodeTypeDescriptor {
        TransactionNodeDescriptor(node: self)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, radius
        case amount, transactionDate, transactionDescription
        case transactionType, categoryID, payerID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? Constants.App.nodeModelRadius

        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)

        // Decode Decimal as string (standard approach)
        let amountString = try container.decode(String.self, forKey: .amount)
        amount = Decimal(string: amountString) ?? 0

        transactionDate = try container.decode(Date.self, forKey: .transactionDate)
        transactionDescription = try container.decode(String.self, forKey: .transactionDescription)
        transactionType = try container.decode(TransactionType.self, forKey: .transactionType)
        categoryID = try container.decodeIfPresent(NodeID.self, forKey: .categoryID)
        payerID = try container.decodeIfPresent(NodeID.self, forKey: .payerID)

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
        try container.encode(amount.description, forKey: .amount)  // Encode Decimal as string
        try container.encode(transactionDate, forKey: .transactionDate)
        try container.encode(transactionDescription, forKey: .transactionDescription)
        try container.encode(transactionType, forKey: .transactionType)
        try container.encodeIfPresent(categoryID, forKey: .categoryID)
        try container.encodeIfPresent(payerID, forKey: .payerID)
    }
}

// MARK: - Equatable
@available(iOS 16.0, watchOS 9.0, *)
extension TransactionNode {
    public static func == (lhs: TransactionNode, rhs: TransactionNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.label == rhs.label &&
        lhs.amount == rhs.amount &&
        lhs.transactionDate == rhs.transactionDate &&
        lhs.transactionType == rhs.transactionType
    }
}
