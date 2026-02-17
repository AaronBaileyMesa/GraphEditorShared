// Sources/GraphEditorShared/HomeEconomics/ChoiceNodeDescriptor.swift

import SwiftUI
import Foundation

@available(iOS 16.0, watchOS 9.0, *)
struct ChoiceNodeDescriptor: NodeTypeDescriptor {
    let node: ChoiceNode

    var mass: CGFloat { 0.7 }
    var physicsRadius: CGFloat { node.radius }
    var constraints: [NodeConstraint] { [] }
    
    var renderer: NodeRenderer { CircleNodeRenderer() }
    var visualMultiplier: CGFloat { 0.8 }
    var baseFillColor: Color { node.fillColor }
    var icon: NodeIcon? { node.isSelected ? .systemName("checkmark") : nil }
    
    var tapBehavior: NodeTapBehavior { .select }
    var isCollapsible: Bool { false }
    var dragBehavior: NodeDragBehavior? { nil }

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let choice = node as? ChoiceNode else { return [] }
        
        return [
            .info([
                .text(choice.choiceText),
                .label("Selected", choice.isSelected ? "Yes" : "No")
            ]),
            .actions([
                .button(choice.isSelected ? "Deselect" : "Select") { context.dismiss() },
                .button("Edit Choice") { context.dismiss() }
            ])
        ]
    }

    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet {
        .init(
            tap: .click,
            stateChange: node.isSelected ? .success : .click
        )
    }
}
