// Sources/GraphEditorShared/Constraints/SeatingGroupConstraint.swift

import Foundation
import CoreGraphics

/// Manages table seating group - fixes table and seated persons
@available(iOS 16.0, watchOS 9.0, *)
public struct SeatingGroupConstraint: NodeConstraint {
    public let tableID: NodeID
    public let seatedPersons: [NodeID]

    public init(tableID: NodeID, seatedPersons: [NodeID]) {
        self.tableID = tableID
        self.seatedPersons = seatedPersons
    }

    public func apply(
        to node: any NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        if node.id == tableID {
            // Keep table fixed at its original position from before physics (prevents physics forces from moving it)
            // User dragging will still work because drag gestures directly update position
            return context.originalPositions[tableID] ?? node.position
        } else if seatedPersons.contains(node.id) {
            // Position person relative to table
            guard let tableNode = context.allNodes.first(where: { $0.id == tableID }),
                  let table = tableNode as? TableNode else {
                return node.position  // Fallback: keep current position if table not found
            }

            // Find which seat this person occupies
            if let seatPosition = table.seatingAssignments.first(where: { $0.value == node.id })?.key {
                // Calculate position based on table's current position and the seat offset
                return table.seatPosition(for: seatPosition)
            }
            return node.position  // Fallback: keep current position if not in seating assignments
        }
        return nil  // Not part of this group
    }

    public func affectedNodeIDs() -> Set<NodeID> {
        var ids = Set(seatedPersons)
        ids.insert(tableID)
        return ids
    }
}
