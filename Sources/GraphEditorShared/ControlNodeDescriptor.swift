// Sources/GraphEditorShared/ControlNodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for ControlNode (ephemeral UI controls)
@available(iOS 16.0, watchOS 9.0, *)
struct ControlNodeDescriptor: NodeTypeDescriptor {
    let node: ControlNode

    init(node: ControlNode) {
        self.node = node
    }

    var mass: CGFloat { 1.0 }
    var physicsRadius: CGFloat { node.radius }
    var constraints: [NodeConstraint] { [] }

    var renderer: NodeRenderer { CircleNodeRenderer() }
    var visualMultiplier: CGFloat { 1.0 }
    var baseFillColor: Color { node.fillColor }
    var icon: NodeIcon? { .systemName(node.kind.renderIcon) }

    var tapBehavior: NodeTapBehavior {
        .custom { node in
            guard let control = node as? ControlNode else { return node }
            return control.handlingTap()
        }
    }
    var isCollapsible: Bool { false }
    var dragBehavior: NodeDragBehavior? { nil }

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let control = node as? ControlNode else { return [] }

        return [
            .info([
                .text("Control: \(control.kind.rawValue)")
            ]),
            .actions([
                .button("Activate") { context.dismiss() }
            ])
        ]
    }

    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet {
        .init(
            tap: .click,
            stateChange: .success
        )
    }
}
