// GraphEditorShared/Sources/GraphEditorShared/HitTestHelper.swift

import CoreGraphics
import os.log  // For standardized logging

private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "hit_test")

/// Context for hit testing (matches GestureContext from GraphGesturesModifier).
public struct HitTestContext {
    public init(zoomScale: CGFloat, offset: CGSize, viewSize: CGSize, effectiveCentroid: CGPoint) {
          self.zoomScale = zoomScale
          self.offset = offset
          self.viewSize = viewSize
          self.effectiveCentroid = effectiveCentroid
      }
    
    public let zoomScale: CGFloat
    public let offset: CGSize
    public let viewSize: CGSize
    public let effectiveCentroid: CGPoint
}

/// Helper for performing hit tests on nodes and edges in screen space.
public struct HitTestHelper {
    
    /// Finds the closest node to a screen position, if within hit radius.
    /// - Returns: The closest node, or nil if none hit.
    public static func closestNode(at screenPos: CGPoint, visibleNodes: [any NodeProtocol], context: HitTestContext) -> (any NodeProtocol)? {
        var closest: (node: (any NodeProtocol)?, dist: CGFloat) = (nil, .infinity)
        let minHitRadius: CGFloat = 10.0  // Minimum tappable radius in screen points
        let padding: CGFloat = 5.0  // Extra forgiveness
        
        for node in visibleNodes {
            let safeZoom = max(context.zoomScale, 0.1)
            let nodeScreenPos = CoordinateTransformer.modelToScreen(
                node.position,
                effectiveCentroid: context.effectiveCentroid,
                zoomScale: safeZoom,
                offset: context.offset,
                viewSize: context.viewSize
            )
            let dist = hypot(screenPos.x - nodeScreenPos.x, screenPos.y - nodeScreenPos.y)
            let visibleRadius = node.radius * safeZoom
            let nodeHitRadius = max(minHitRadius, visibleRadius) + padding
            
            if dist <= nodeHitRadius && dist < closest.dist {
                closest = (node, dist)
            }
        }
        
        #if DEBUG
        if let node = closest.node {
            logger.debug("Hit closest node \(node.label) at dist \(closest.dist)")
        } else {
            logger.debug("No node hit at screen pos \(String(describing: screenPos))")
        }
        #endif
        
        return closest.node
    }
    
    /// Finds the closest edge to a screen position, if within hit radius.
    /// - Returns: The closest edge, or nil if none hit.
    public static func closestEdge(at screenPos: CGPoint, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], context: HitTestContext) -> GraphEdge? {
        var closest: (edge: GraphEdge?, dist: CGFloat) = (nil, .infinity)
        let hitScreenRadius: CGFloat = 10.0  // Adjustable; smaller for edges to avoid node overlap
        
        for edge in visibleEdges {
            guard let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                  let toNode = visibleNodes.first(where: { $0.id == edge.target }) else { continue }
            
            let safeZoom = max(context.zoomScale, 0.1)
            let fromScreen = CoordinateTransformer.modelToScreen(
                fromNode.position,
                effectiveCentroid: context.effectiveCentroid,
                zoomScale: safeZoom,
                offset: context.offset,
                viewSize: context.viewSize
            )
            let toScreen = CoordinateTransformer.modelToScreen(
                toNode.position,
                effectiveCentroid: context.effectiveCentroid,
                zoomScale: safeZoom,
                offset: context.offset,
                viewSize: context.viewSize
            )
            
            let dist = pointToLineDistance(point: screenPos, from: fromScreen, target: toScreen)
            
            if dist <= hitScreenRadius && dist < closest.dist {
                closest = (edge, dist)
            }
        }
        
        #if DEBUG
        if let edge = closest.edge {
            logger.debug("Hit closest edge \(edge.id.uuidString.prefix(8)) at dist \(closest.dist)")
        } else {
            logger.debug("No edge hit at screen pos \(String(describing: screenPos))")
        }
        #endif
        
        return closest.edge
    }
    
    // Helper: Distance from point to line segment (extracted for clarity; add if not already in utilities)
    private static func pointToLineDistance(point: CGPoint, from: CGPoint, target: CGPoint) -> CGFloat {
        let lineVec = CGVector(dx: target.x - from.x, dy: target.y - from.y)
        let pointVec = CGVector(dx: point.x - from.x, dy: point.y - from.y)
        let lineLen = hypot(lineVec.dx, lineVec.dy)
        if lineLen == 0 { return hypot(pointVec.dx, pointVec.dy) }
        
        // Parametric position along the segment clamped to [0, 1]
        let clampedT = max(0, min(1, (pointVec.dx * lineVec.dx + pointVec.dy * lineVec.dy) / (lineLen * lineLen)))
        let proj = CGPoint(x: from.x + clampedT * lineVec.dx, y: from.y + clampedT * lineVec.dy)
        return hypot(point.x - proj.x, point.y - proj.y)
    }
}
