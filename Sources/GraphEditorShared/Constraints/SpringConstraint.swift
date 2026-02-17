// Sources/GraphEditorShared/Constraints/SpringConstraint.swift

import Foundation
import CoreGraphics

/// Applies spring force toward target position (soft constraint)
@available(iOS 16.0, watchOS 9.0, *)
public struct SpringConstraint: NodeConstraint {
    public let targetPosition: CGPoint
    public let stiffness: CGFloat
    public let damping: CGFloat

    public init(targetPosition: CGPoint, stiffness: CGFloat = 0.1, damping: CGFloat = 0.9) {
        self.targetPosition = targetPosition
        self.stiffness = stiffness
        self.damping = damping
    }

    public func apply(
        to node: any NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        // Blend physics position toward target using spring force
        let delta = CGPoint(
            x: targetPosition.x - proposedPosition.x,
            y: targetPosition.y - proposedPosition.y
        )

        let force = CGPoint(
            x: delta.x * stiffness - node.velocity.x * damping,
            y: delta.y * stiffness - node.velocity.y * damping
        )

        return CGPoint(
            x: proposedPosition.x + force.x * context.deltaTime,
            y: proposedPosition.y + force.y * context.deltaTime
        )
    }

    public func affectedNodeIDs() -> Set<NodeID> {
        []
    }
}
