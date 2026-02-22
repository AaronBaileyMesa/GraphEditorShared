// PeopleListNodeDescriptor.swift
// GraphEditorShared
//
// Type descriptor for PeopleListNode

import SwiftUI
import Foundation

/// Type descriptor for PeopleListNode
@available(iOS 16.0, watchOS 9.0, *)
struct PeopleListNodeDescriptor: NodeTypeDescriptor {
    let node: PeopleListNode

    init(node: PeopleListNode) {
        self.node = node
    }

    var mass: CGFloat { 
        // When expanded with grid constraint, make immovable to prevent drift
        // When collapsed, use normal mass for physics positioning
        node.isExpanded && !node.children.isEmpty ? 1000.0 : 3.0
    }
    var physicsRadius: CGFloat { node.radius }
    var constraints: [NodeConstraint] {
        // When expanded, arrange children in a vertical list (table-style)
        guard node.isExpanded && !node.children.isEmpty else {
            return []
        }
        
        #if DEBUG
        print("🔧 PeopleListNode '\(node.name)' creating VerticalListConstraint for \(node.children.count) children: \(node.children.map { $0.uuidString.prefix(8) })")
        #endif
        
        // Use vertical list layout for table-style presentation
        // Each row: [icon] Name
        return [
            VerticalListConstraint(
                parentID: node.id,
                childIDs: node.children,
                rowHeight: 28.0,  // Compact row spacing
                offsetFromParent: CGPoint(x: -60, y: 50)  // Shifted right with extra margin for selection stroke
            )
        ]
    }

    var renderer: NodeRenderer { PeopleListNodeRenderer() }
    var visualMultiplier: CGFloat { 1.5 }
    var baseFillColor: Color { node.fillColor }
    var icon: NodeIcon? { .systemName("person.3.fill") }

    var tapBehavior: NodeTapBehavior { .toggleExpansion }
    var isCollapsible: Bool { node.isCollapsible }
    var dragBehavior: NodeDragBehavior? { nil }

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let peopleList = node as? PeopleListNode else { return [] }

        let countText = peopleList.children.count == 1 ? "1 person" : "\(peopleList.children.count) people"

        return [
            .info([
                .text(peopleList.name),
                .label("Count", countText)
            ]),
            .actions([
                .button("Add Person") { context.dismiss() },
                .button(peopleList.isExpanded ? "Collapse" : "Expand") { context.dismiss() }
            ])
        ]
    }

    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet { .default }
}
