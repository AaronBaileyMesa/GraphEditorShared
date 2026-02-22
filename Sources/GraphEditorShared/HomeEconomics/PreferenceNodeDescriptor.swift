// Sources/GraphEditorShared/HomeEconomics/PreferenceNodeDescriptor.swift

import SwiftUI
import Foundation

@available(iOS 16.0, watchOS 9.0, *)
struct PreferenceNodeDescriptor: NodeTypeDescriptor {
    let node: PreferenceNode

    var mass: CGFloat { 1.5 }
    var physicsRadius: CGFloat { node.radius }
    var constraints: [NodeConstraint] { [] }
    
    var renderer: NodeRenderer { CircleNodeRenderer() }
    var visualMultiplier: CGFloat { 1.2 }
    var baseFillColor: Color { node.fillColor }
    var icon: NodeIcon? { .systemName("doc.text.fill") }
    
    var tapBehavior: NodeTapBehavior { .select }
    var isCollapsible: Bool { false }
    var dragBehavior: NodeDragBehavior? { nil }

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let preference = node as? PreferenceNode else { return [] }
        
        return [
            .info([
                .text("Preference Summary"),
                .text(preference.summary)
            ]),
            .actions([
                .button("View Details") { context.dismiss() },
                .button("Apply to Recipe") { context.dismiss() }
            ])
        ]
    }

    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet { .default }
}
