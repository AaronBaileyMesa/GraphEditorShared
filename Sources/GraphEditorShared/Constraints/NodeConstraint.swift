// Sources/GraphEditorShared/Constraints/NodeConstraint.swift

import Foundation
import CoreGraphics

/// Represents a physics constraint applied to a node.
/// Constraints allow declarative control over node positioning without
/// scattered type-checking throughout the physics engine.
@available(iOS 16.0, watchOS 9.0, *)
public protocol NodeConstraint {
    /// Apply constraint and return modified position (or nil to use physics position)
    /// - Parameters:
    ///   - node: The node being constrained
    ///   - proposedPosition: The position calculated by physics
    ///   - context: Additional context for constraint evaluation
    /// - Returns: Constrained position, or nil to use proposedPosition
    func apply(
        to node: any NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint?

    /// IDs of nodes this constraint affects (for dependency tracking)
    func affectedNodeIDs() -> Set<NodeID>
}

/// Context provided during constraint evaluation
@available(iOS 16.0, watchOS 9.0, *)
public struct ConstraintContext {
    public let allNodes: [any NodeProtocol]
    public let deltaTime: CGFloat
    public let simulationBounds: CGSize
    public let originalPositions: [NodeID: CGPoint]  // Positions before physics step

    public init(allNodes: [any NodeProtocol], deltaTime: CGFloat, simulationBounds: CGSize, originalPositions: [NodeID: CGPoint] = [:]) {
        self.allNodes = allNodes
        self.deltaTime = deltaTime
        self.simulationBounds = simulationBounds
        self.originalPositions = originalPositions
    }

    /// Helper to find nodes by ID
    public func node(withID id: NodeID) -> (any NodeProtocol)? {
        allNodes.first { $0.id == id }
    }
}
