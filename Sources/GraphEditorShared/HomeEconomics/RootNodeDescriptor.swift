// Sources/GraphEditorShared/HomeEconomics/RootNodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for RootNode
@available(iOS 16.0, watchOS 9.0, *)
struct RootNodeDescriptor: NodeTypeDescriptor {
    let node: RootNode

    init(node: RootNode) {
        self.node = node
    }

    // MARK: - Physics Configuration

    var mass: CGFloat {
        1000.0  // Immovable - extremely high mass
    }

    var physicsRadius: CGFloat {
        node.radius
    }

    var constraints: [NodeConstraint] {
        []  // No constraints - fixed at origin
    }

    // MARK: - Visual Configuration

    var renderer: NodeRenderer {
        RootNodeRenderer()
    }

    var visualMultiplier: CGFloat {
        1.5  // Larger than normal nodes
    }

    var baseFillColor: Color {
        Color.gray.opacity(0.8)  // Light gray
    }

    var icon: NodeIcon? {
        nil  // Custom renderer handles the + symbol
    }

    // MARK: - Interaction Configuration

    var tapBehavior: NodeTapBehavior {
        .select  // Select to show control nodes
    }

    var isCollapsible: Bool {
        false  // Cannot collapse
    }

    var dragBehavior: NodeDragBehavior? {
        nil  // Immovable
    }

    // MARK: - Menu Configuration

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let root = node as? RootNode else { return [] }

        return [
            .info([
                .text(root.name)  // Editable name field
            ]),
            .actions([
                .button("Reset Graph") {
                    // TODO: Wire up reset graph action
                    context.dismiss()
                }
            ])
        ]
    }

    // MARK: - Animation Configuration

    var animations: NodeAnimationSet {
        .default
    }

    // MARK: - Haptic Configuration

    var haptics: NodeHapticSet {
        .init(
            tap: .click,
            drag: .click,  // Should never drag, but just in case
            drop: .success,
            stateChange: .success
        )
    }
}
