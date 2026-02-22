// Sources/GraphEditorShared/HomeEconomics/DecisionNodeDescriptor.swift

import SwiftUI
import Foundation

@available(iOS 16.0, watchOS 9.0, *)
struct DecisionNodeDescriptor: NodeTypeDescriptor {
    let node: DecisionNode

    var mass: CGFloat { 1.2 }
    var physicsRadius: CGFloat { node.radius }
    var constraints: [NodeConstraint] { [] }
    
    var renderer: NodeRenderer { CircleNodeRenderer() }
    var visualMultiplier: CGFloat { 1.1 }
    var baseFillColor: Color { node.fillColor }
    var icon: NodeIcon? { .systemName("questionmark.circle.fill") }
    
    var tapBehavior: NodeTapBehavior { .select }
    var isCollapsible: Bool { true }
    var dragBehavior: NodeDragBehavior? { nil }

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let decision = node as? DecisionNode else { return [] }
        
        return [
            .info([
                .text(decision.question)
            ]),
            .actions([
                .button("Add Choice") { context.dismiss() },
                .button("Edit Question") { context.dismiss() }
            ])
        ]
    }

    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet { .default }
}
