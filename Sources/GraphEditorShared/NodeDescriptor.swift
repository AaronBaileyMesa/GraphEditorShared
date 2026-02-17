// Sources/GraphEditorShared/NodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for generic Node (fallback/default)
@available(iOS 16.0, watchOS 9.0, *)
struct GenericNodeDescriptor: NodeTypeDescriptor {
    let node: Node

    init(node: Node) {
        self.node = node
    }

    var mass: CGFloat { 1.0 }
    var physicsRadius: CGFloat { node.radius }
    var constraints: [NodeConstraint] { [] }

    var renderer: NodeRenderer { CircleNodeRenderer() }
    var visualMultiplier: CGFloat { 1.0 }
    var baseFillColor: Color { node.fillColor }
    var icon: NodeIcon? { nil }

    var tapBehavior: NodeTapBehavior {
        node.isCollapsible ? .toggleExpansion : .select
    }
    var isCollapsible: Bool { node.isCollapsible }
    var dragBehavior: NodeDragBehavior? { nil }

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let genericNode = node as? Node else { return [] }

        var infoItems: [MenuItem] = [
            .label("Node", "\(genericNode.label)")
        ]

        if !genericNode.contents.isEmpty {
            for (index, content) in genericNode.contents.enumerated() {
                switch content {
                case .string(let str):
                    infoItems.append(.label("Content \(index + 1)", str))
                case .number(let num):
                    infoItems.append(.label("Content \(index + 1)", "\(num)"))
                case .date(let date):
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    infoItems.append(.label("Content \(index + 1)", formatter.string(from: date)))
                case .boolean(let bool):
                    infoItems.append(.label("Content \(index + 1)", bool ? "Yes" : "No"))
                }
            }
        }

        if !genericNode.children.isEmpty {
            infoItems.append(.label("Children", "\(genericNode.children.count)"))
        }

        return [
            .info(infoItems),
            .actions([
                .button("Edit Node") { context.dismiss() }
            ])
        ]
    }

    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet { .default }
}
