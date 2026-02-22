// Sources/GraphEditorShared/Constraints/RelativePositionConstraint.swift

import Foundation
import CoreGraphics

/// Maintains position relative to another node (e.g., seated person at table)
@available(iOS 16.0, watchOS 9.0, *)
public struct RelativePositionConstraint: NodeConstraint {
    public let anchorNodeID: NodeID
    public let offset: CGPoint

    public init(anchorNodeID: NodeID, offset: CGPoint) {
        self.anchorNodeID = anchorNodeID
        self.offset = offset
    }

    public func apply(
        to node: any NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        guard let anchor = context.node(withID: anchorNodeID) else {
            return nil  // Anchor not found, use physics
        }

        // Position relative to anchor
        return CGPoint(
            x: anchor.position.x + offset.x,
            y: anchor.position.y + offset.y
        )
    }

    public func affectedNodeIDs() -> Set<NodeID> {
        [anchorNodeID]
    }
}
