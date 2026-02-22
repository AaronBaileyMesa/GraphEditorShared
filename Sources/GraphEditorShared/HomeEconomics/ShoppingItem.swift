//
//  ShoppingItem.swift
//  GraphEditorShared
//
//  Represents an item on a generated shopping list
//

import Foundation

/// A single item on a generated taco night shopping list
public struct ShoppingItem: Identifiable {
    public let id: UUID
    public let name: String
    public let quantity: Decimal
    public let unit: String

    public init(id: UUID = UUID(), name: String, quantity: Decimal, unit: String) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }

    /// Formatted display string for quantity + unit (e.g. "1.5 lb", "3 count")
    public var quantityString: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let qtyString = formatter.string(from: quantity as NSDecimalNumber) ?? "\(quantity)"
        return "\(qtyString) \(unit)"
    }
}
