// Sources/GraphEditorShared/HomeEconomics/TableNodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for TableNode with seating constraints and custom rendering
@available(iOS 16.0, watchOS 9.0, *)
struct TableNodeDescriptor: NodeTypeDescriptor {
    let node: TableNode

    init(node: TableNode) {
        self.node = node
    }

    // MARK: - Physics Configuration

    var mass: CGFloat {
        30.0  // Tables are heavy
    }

    var physicsRadius: CGFloat {
        node.radius
    }

    var constraints: [NodeConstraint] {
        // Only apply seating constraint if there are seated persons
        guard !node.seatingAssignments.isEmpty else {
            return []
        }

        return [
            SeatingGroupConstraint(
                tableID: node.id,
                seatedPersons: Array(node.seatingAssignments.values)
            )
        ]
    }

    // MARK: - Visual Configuration

    var renderer: NodeRenderer {
        RectangleNodeRenderer(
            cornerRadius: 8,
            aspectRatio: node.tableWidth / node.tableLength  // width/height
        )
    }

    var visualMultiplier: CGFloat {
        max(node.tableLength, node.tableWidth) / (2 * node.radius)
    }

    var baseFillColor: Color {
        .brown
    }

    var icon: NodeIcon? {
        nil
    }

    // MARK: - Interaction Configuration

    var tapBehavior: NodeTapBehavior {
        .none  // Tables don't respond to taps
    }

    var isCollapsible: Bool {
        false  // Tables don't collapse
    }

    var dragBehavior: NodeDragBehavior? {
        // Tables with seated persons have custom drag behavior
        guard !node.seatingAssignments.isEmpty else {
            return nil
        }
        return TableDragBehavior(
            tableID: node.id,
            seatingAssignments: node.seatingAssignments,
            tableNode: node
        )
    }

    // MARK: - Menu Configuration

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let table = node as? TableNode else { return [] }
        
        return [
            .info([
                .text("Table: \(table.name)"),
                .text("\(table.totalSeats) seats"),
                .text("\(table.seatingAssignments.count) occupied")
            ]),
            .actions([
                .button("Edit Seating") {
                    // This will be connected to the actual sheet presenter
                    context.dismiss()
                },
                .button("Remove Table") {
                    context.dismiss()
                }
            ])
        ]
    }

    // MARK: - Animation Configuration

    var animations: NodeAnimationSet {
        .init(
            selection: .pulse(color: .brown.opacity(0.3), duration: 0.3),
            deselection: .fadeOut(duration: 0.2)
        )
    }

    // MARK: - Haptic Configuration

    var haptics: NodeHapticSet {
        .init(
            tap: .click,
            drag: .directionUp,  // Slightly stronger feedback when dragging a table
            drop: .directionDown,  // Satisfying feedback when placing the table
            stateChange: .success  // Success haptic when assigning/removing seats
        )
    }
}

// MARK: - Custom Drag Behavior for Tables

/// Custom drag behavior that moves table and all seated persons together
@available(iOS 16.0, watchOS 9.0, *)
struct TableDragBehavior: NodeDragBehavior {
    let tableID: NodeID
    let seatingAssignments: [Int: NodeID]
    let tableNode: TableNode

    func applyDrag(
        to node: any NodeProtocol,
        translation: CGSize,
        context: DragContext
    ) -> CGPoint {
        // When dragging a table with seated persons, the table position updates normally
        // The constraint system will handle keeping seated persons in their relative positions
        return CGPoint(
            x: node.position.x + translation.width / context.zoomScale,
            y: node.position.y + translation.height / context.zoomScale
        )
    }
}
