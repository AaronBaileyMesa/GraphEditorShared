// Sources/GraphEditorShared/HomeEconomics/TransactionNodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for TransactionNode
@available(iOS 16.0, watchOS 9.0, *)
struct TransactionNodeDescriptor: NodeTypeDescriptor {
    let node: TransactionNode

    init(node: TransactionNode) {
        self.node = node
    }

    var mass: CGFloat { 1.2 }
    var physicsRadius: CGFloat { node.radius }
    var constraints: [NodeConstraint] { [] }

    var renderer: NodeRenderer { CircleNodeRenderer() }
    var visualMultiplier: CGFloat { 1.2 }
    var baseFillColor: Color { node.fillColor }
    var icon: NodeIcon? {
        node.transactionType == .income ? .systemName("arrow.down.circle.fill") : .systemName("arrow.up.circle.fill")
    }

    var tapBehavior: NodeTapBehavior { .select }
    var isCollapsible: Bool { false }
    var dragBehavior: NodeDragBehavior? { nil }

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let transaction = node as? TransactionNode else { return [] }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        let amountString = currencyFormatter.string(from: transaction.amount as NSNumber) ?? "\(transaction.amount)"

        return [
            .info([
                .text(transaction.transactionDescription),
                .label("Amount", amountString),
                .label("Date", formatter.string(from: transaction.transactionDate)),
                .label("Type", transaction.transactionType.rawValue.capitalized)
            ]),
            .actions([
                .button("Edit Transaction") { context.dismiss() },
                .button("Delete") { context.dismiss() }
            ])
        ]
    }

    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet { .default }
}
