// Sources/GraphEditorShared/Constraints/GridConstraint.swift

import Foundation
import CoreGraphics

/// Constraint that arranges child nodes in a grid pattern around a parent node
@available(iOS 16.0, watchOS 9.0, *)
public struct GridConstraint: NodeConstraint {
    public let parentID: NodeID
    public let childIDs: [NodeID]
    public let columns: Int
    public let spacing: CGFloat
    public let offsetFromParent: CGPoint  // Offset of grid top-left from parent center
    
    public init(
        parentID: NodeID,
        childIDs: [NodeID],
        columns: Int = 3,
        spacing: CGFloat = 60.0,
        offsetFromParent: CGPoint = CGPoint(x: -60, y: 60)
    ) {
        self.parentID = parentID
        self.childIDs = childIDs
        self.columns = columns
        self.spacing = spacing
        self.offsetFromParent = offsetFromParent
    }
    
    public func apply(
        to node: any NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        // Only apply to child nodes in our list
        guard let childIndex = childIDs.firstIndex(of: node.id) else {
            return nil
        }
        
        // Find parent node
        guard let parent = context.node(withID: parentID) else {
            return nil
        }
        
        // Calculate grid position
        let row = childIndex / columns
        let col = childIndex % columns
        
        // Position relative to parent
        let gridX = parent.position.x + offsetFromParent.x + CGFloat(col) * spacing
        let gridY = parent.position.y + offsetFromParent.y + CGFloat(row) * spacing
        
        return CGPoint(x: gridX, y: gridY)
    }
    
    public func affectedNodeIDs() -> Set<NodeID> {
        Set(childIDs)
    }
}
