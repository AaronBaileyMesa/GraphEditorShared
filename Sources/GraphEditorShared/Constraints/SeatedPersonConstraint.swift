// Sources/GraphEditorShared/Constraints/SeatedPersonConstraint.swift

import Foundation
import CoreGraphics

/// Constraint for a person node that keeps them at their assigned seat
@available(iOS 16.0, watchOS 9.0, *)
public struct SeatedPersonConstraint: NodeConstraint {
    public let personID: NodeID

    public init(personID: NodeID) {
        self.personID = personID
    }

    public func apply(
        to node: any NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        // Only apply to the person this constraint is for
        guard node.id == personID else {
            return nil
        }

        // Find the table this person is seated at
        for tableNode in context.allNodes {
            guard var table = tableNode as? TableNode else { continue }

            // Check if this person is in the table's seating assignments
            if let seatPosition = table.seatingAssignments.first(where: { $0.value == personID })?.key {
                // Use the table's original position (before physics) to avoid oscillation
                // The table constraint will restore it to this position anyway
                if let originalTablePos = context.originalPositions[table.id] {
                    table.position = originalTablePos
                }
                // Calculate and return the correct position for this seat
                return table.seatPosition(for: seatPosition)
            }
        }

        // Person is not seated at any table - allow free movement
        return nil
    }

    public func affectedNodeIDs() -> Set<NodeID> {
        [personID]
    }
}
