// VerticalListConstraint.swift
// GraphEditorShared
//
// Constraint that arranges child nodes in a vertical list (table-style)

import Foundation
import CoreGraphics

/// Constraint that arranges child nodes in a vertical list with fixed spacing
@available(iOS 16.0, watchOS 9.0, *)
public struct VerticalListConstraint: NodeConstraint {
    public let parentID: NodeID
    public let childIDs: [NodeID]
    public let rowHeight: CGFloat  // Vertical spacing between rows
    public let offsetFromParent: CGPoint  // Offset of first row from parent center
    
    public init(
        parentID: NodeID,
        childIDs: [NodeID],
        rowHeight: CGFloat = 40.0,  // Typography-based spacing
        offsetFromParent: CGPoint = CGPoint(x: 0, y: 35)
    ) {
        self.parentID = parentID
        self.childIDs = childIDs
        self.rowHeight = rowHeight
        self.offsetFromParent = offsetFromParent
    }
    
    public func apply(
        to node: any NodeProtocol,
        proposedPosition: CGPoint,
        context: ConstraintContext
    ) -> CGPoint? {
        // Only apply to child nodes in our list
        guard let childIndex = childIDs.firstIndex(of: node.id) else {
            #if DEBUG
            print("⚠️ VerticalListConstraint: node \(node.id.uuidString.prefix(8)) not in childIDs")
            #endif
            return nil
        }
        
        // Find parent node
        guard let parent = context.node(withID: parentID) else {
            #if DEBUG
            print("⚠️ VerticalListConstraint: parent \(parentID.uuidString.prefix(8)) not found in context")
            #endif
            return nil
        }
        
        // Calculate vertical list position
        // All nodes aligned on same X (left-aligned with icon)
        let listX = parent.position.x + offsetFromParent.x
        let listY = parent.position.y + offsetFromParent.y + CGFloat(childIndex) * rowHeight
        
        let result = CGPoint(x: listX, y: listY)
        
        #if DEBUG
        print("✅ VerticalListConstraint: applied to node \(node.id.uuidString.prefix(8)) [index \(childIndex)]: (\(proposedPosition.x), \(proposedPosition.y)) → (\(result.x), \(result.y))")
        #endif
        
        return result
    }
    
    public func affectedNodeIDs() -> Set<NodeID> {
        Set(childIDs)
    }
}
