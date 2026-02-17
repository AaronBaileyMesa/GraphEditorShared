// Sources/GraphEditorShared/HomeEconomics/IngredientNodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for IngredientNode
@available(iOS 16.0, watchOS 9.0, *)
struct IngredientNodeDescriptor: NodeTypeDescriptor {
    let node: IngredientNode

    init(node: IngredientNode) {
        self.node = node
    }

    var mass: CGFloat { 0.8 }
    var physicsRadius: CGFloat { node.radius }
    var constraints: [NodeConstraint] { [] }
    
    var renderer: NodeRenderer { CircleNodeRenderer() }
    var visualMultiplier: CGFloat { 0.9 }
    var baseFillColor: Color { node.fillColor }
    var icon: NodeIcon? { .systemName("leaf.fill") }
    
    var tapBehavior: NodeTapBehavior { .select }
    var isCollapsible: Bool { false }
    var dragBehavior: NodeDragBehavior? { nil }

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let ingredient = node as? IngredientNode else { return [] }
        
        return [
            .info([
                .text(ingredient.name),
                .label("Quantity", "\(ingredient.quantity)"),
                .label("Unit", ingredient.unit.rawValue)
            ]),
            .actions([
                .button("Edit Ingredient") { context.dismiss() }
            ])
        ]
    }

    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet { .default }
}
