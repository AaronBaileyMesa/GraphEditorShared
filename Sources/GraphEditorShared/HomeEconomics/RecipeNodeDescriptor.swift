// Sources/GraphEditorShared/HomeEconomics/RecipeNodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for RecipeNode
@available(iOS 16.0, watchOS 9.0, *)
struct RecipeNodeDescriptor: NodeTypeDescriptor {
    let node: RecipeNode

    init(node: RecipeNode) {
        self.node = node
    }

    var mass: CGFloat { 1.5 }
    var physicsRadius: CGFloat { node.radius }
    var constraints: [NodeConstraint] { [] }
    
    var renderer: NodeRenderer { CircleNodeRenderer() }
    var visualMultiplier: CGFloat { 1.2 }
    var baseFillColor: Color { node.fillColor }
    var icon: NodeIcon? { .systemName("book.fill") }
    
    var tapBehavior: NodeTapBehavior { .toggleExpansion }
    var isCollapsible: Bool { true }
    var dragBehavior: NodeDragBehavior? { nil }

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let recipe = node as? RecipeNode else { return [] }
        
        return [
            .info([
                .text(recipe.name),
                .label("Servings", "\(recipe.servings)"),
                .label("Time", "\(recipe.prepTime + recipe.cookTime) min")
            ]),
            .actions([
                .button("Scale Recipe") { context.dismiss() },
                .button("Clone Recipe") { context.dismiss() },
                .button("Edit Recipe") { context.dismiss() }
            ])
        ]
    }

    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet { .default }
}
