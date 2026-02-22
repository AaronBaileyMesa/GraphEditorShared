// Sources/GraphEditorShared/HomeEconomics/CategoryNodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for CategoryNode
@available(iOS 16.0, watchOS 9.0, *)
struct CategoryNodeDescriptor: NodeTypeDescriptor {
    let node: CategoryNode

    init(node: CategoryNode) {
        self.node = node
    }

    var mass: CGFloat { 2.5 }
    var physicsRadius: CGFloat { node.radius }
    var constraints: [NodeConstraint] { [] }

    var renderer: NodeRenderer { CircleNodeRenderer() }
    var visualMultiplier: CGFloat { 1.5 }
    var baseFillColor: Color { node.fillColor }
    var icon: NodeIcon? { .systemName(node.icon) }

    var tapBehavior: NodeTapBehavior { .toggleExpansion }
    var isCollapsible: Bool { node.isCollapsible }
    var dragBehavior: NodeDragBehavior? { nil }

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let category = node as? CategoryNode else { return [] }

        return [
            .info([
                .text(category.name),
                .label("Transactions", "\(category.children.count)")
            ]),
            .actions([
                .button("Add Transaction") { context.dismiss() },
                .button("Edit Category") { context.dismiss() }
            ])
        ]
    }

    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet { .default }
}
