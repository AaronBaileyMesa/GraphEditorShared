// Sources/GraphEditorShared/DefaultNodeDescriptor.swift

import SwiftUI
import Foundation

/// Default node descriptor that provides backwards compatibility.
/// This descriptor delegates to the node's existing properties for nodes
/// that haven't yet been migrated to use custom descriptors.
@available(iOS 16.0, watchOS 9.0, *)
public struct DefaultNodeDescriptor: NodeTypeDescriptor {
    let node: any NodeProtocol

    public init(node: any NodeProtocol) {
        self.node = node
    }

    public var mass: CGFloat {
        node.mass
    }

    public var physicsRadius: CGFloat {
        node.radius
    }

    public var constraints: [NodeConstraint] {
        []
    }

    public var renderer: NodeRenderer {
        CircleNodeRenderer()
    }

    public var visualMultiplier: CGFloat {
        1.0
    }

    public var baseFillColor: Color {
        node.fillColor
    }

    public var icon: NodeIcon? {
        nil
    }

    public var tapBehavior: NodeTapBehavior {
        .toggleExpansion
    }

    public var isCollapsible: Bool {
        true
    }

    public var dragBehavior: NodeDragBehavior? {
        nil
    }

    public func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        // Default empty menu - individual node types should override
        []
    }

    public var animations: NodeAnimationSet {
        .default
    }

    public var haptics: NodeHapticSet {
        .default
    }
}
