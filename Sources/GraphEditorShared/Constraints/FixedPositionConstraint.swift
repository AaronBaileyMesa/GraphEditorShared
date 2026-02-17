// Sources/GraphEditorShared/Constraints/FixedPositionConstraint.swift

import Foundation
import CoreGraphics

/// Prevents node from moving (ignores physics)
@available(iOS 16.0, watchOS 9.0, *)
public struct FixedPositionConstraint: NodeConstraint {
    public init() {}

    public func apply(
        to node: any NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        // Return original position, ignoring proposed physics position
        return node.position
    }

    public func affectedNodeIDs() -> Set<NodeID> {
        []
    }
}
