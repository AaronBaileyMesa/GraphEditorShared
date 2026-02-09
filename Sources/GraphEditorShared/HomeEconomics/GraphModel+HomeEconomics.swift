//
//  GraphModel+HomeEconomics.swift
//  GraphEditorShared
//
//  Home economics extensions for GraphModel
//

import Foundation
import CoreGraphics
import SwiftUI

@available(iOS 16.0, watchOS 9.0, *)
extension GraphModel {

    // MARK: - Transaction Operations

    /// Adds a transaction node to the graph
    @MainActor
    public func addTransaction(
        amount: Decimal,
        description: String,
        type: TransactionType,
        categoryID: NodeID? = nil,
        payerID: NodeID? = nil,
        at position: CGPoint
    ) async -> TransactionNode {
        let transaction = TransactionNode(
            label: nextNodeLabel,
            position: position,
            amount: amount,
            transactionDate: Date(),
            description: description,
            transactionType: type,
            categoryID: categoryID,
            payerID: payerID
        )

        let anyNode = AnyNode(transaction)
        nodes.append(anyNode)
        nextNodeLabel += 1

        // Auto-create edges if category/payer specified
        if let catID = categoryID {
            await addEdge(from: transaction.id, target: catID, type: .hierarchy)
        }
        if let payID = payerID {
            await addEdge(from: payID, target: transaction.id, type: .attribution)
        }

        // Note: Saving is handled by caller or auto-save mechanism
        return transaction
    }

    /// Adds a category node
    @MainActor
    public func addCategory(
        name: String,
        color: Color,
        icon: String = "tag.fill",
        at position: CGPoint
    ) async -> CategoryNode {
        let category = CategoryNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            color: color,
            icon: icon
        )

        nodes.append(AnyNode(category))
        nextNodeLabel += 1
        // Note: Saving is handled by caller or auto-save mechanism
        return category
    }

    // MARK: - Query Helpers

    /// Returns all transactions in a category
    @MainActor
    public func transactions(in categoryID: NodeID) -> [TransactionNode] {
        edges
            .filter { $0.target == categoryID && $0.type == .hierarchy }
            .compactMap { edge in
                nodes.first(where: { $0.id == edge.from })?.unwrapped as? TransactionNode
            }
    }

    /// Calculates total spending for a category
    @MainActor
    public func totalSpending(in categoryID: NodeID) -> Decimal {
        transactions(in: categoryID)
            .filter { $0.transactionType == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }
}
