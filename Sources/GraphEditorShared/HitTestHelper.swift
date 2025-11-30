//
//  HitTestHelper.swift
//  GraphEditorShared
//
//  Created by handcart on 11/19/25.
//

import Foundation
import CoreGraphics
import os
import SwiftUI

private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "hit_test")

/// Central hit-testing utilities – now uses the single source-of-truth RenderContext
public struct HitTestHelper {
    
    /// Returns the closest node to a screen point (if within hit radius)
    public static func closestNode(
        at screenPos: CGPoint,
        visibleNodes: [any NodeProtocol],
        renderContext: RenderContext                 // ← the shared one
    ) -> (any NodeProtocol)? {
        var closest: (any NodeProtocol)?
        var minDist = CGFloat.infinity
        
        for node in visibleNodes {
            let nodeScreen = CoordinateTransformer.modelToScreen(node.position, renderContext)
            let dist = hypot(screenPos.x - nodeScreen.x, screenPos.y - nodeScreen.y)
            let hitRadius = node.radius * renderContext.zoomScale * 1.8   // generous for Watch
            
            if dist < hitRadius && dist < minDist {
                minDist = dist
                closest = node
            }
        }
        
        #if DEBUG
        if let node = closest {
            logger.debug("Hit node \(node.label) at distance \(minDist)")
        }
        #endif
        
        return closest
    }
    
    /// Returns the closest edge to a screen point (if within hit radius)
    /// Returns the closest edge to a screen point (if within hit radius)
    public static func closestEdge(
        at screenPos: CGPoint,
        visibleEdges: [GraphEdge],
        visibleNodes: [any NodeProtocol],
        renderContext: RenderContext                 // ← the shared one
    ) -> GraphEdge? {
        var best: (edge: GraphEdge?, distance: CGFloat) = (nil, .infinity)
        let hitRadius: CGFloat = 12.0   // easy to tap on Watch
        
        for edge in visibleEdges {
            guard
                let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                let toNode   = visibleNodes.first(where: { $0.id == edge.target })
            else { continue }
            
            // FIXED: Now using the correct RenderContext overload
            let fromScreen = CoordinateTransformer.modelToScreen(fromNode.position, renderContext)
            let toScreen = CoordinateTransformer.modelToScreen(toNode.position, renderContext)
            
            let dist = pointToLineDistance(point: screenPos, from: fromScreen, to: toScreen)
            
            if dist < hitRadius && dist < best.distance {
                best = (edge, dist)
            }
        }
        
        #if DEBUG
        if let edge = best.edge {
            logger.debug("Hit edge \(edge.id.uuidString.prefix(8)) at distance \(best.distance)")
        }
        #endif
        
        return best.edge
    }
    
    /// Classic point-to-line-segment distance (clamped)
    public static func pointToLineDistance(
        point: CGPoint,
        from startPoint: CGPoint,
        to endPoint: CGPoint
    ) -> CGFloat {
        let lineVector = CGVector(dx: endPoint.x - startPoint.x, dy: endPoint.y - startPoint.y)
        let pointVector = CGVector(dx: point.x - startPoint.x, dy: point.y - startPoint.y)
        
        let lineLengthSquared = lineVector.dx * lineVector.dx + lineVector.dy * lineVector.dy
        
        // If start and end are the same point, return distance to that point
        guard lineLengthSquared > 0 else {
            return hypot(pointVector.dx, pointVector.dy)
        }
        
        // Project point onto the line segment (clamp t to [0, 1])
        let projectionParameter = max(0, min(1,
            (pointVector.dx * lineVector.dx + pointVector.dy * lineVector.dy) / lineLengthSquared
        ))
        
        let closestPointOnLine = CGPoint(
            x: startPoint.x + projectionParameter * lineVector.dx,
            y: startPoint.y + projectionParameter * lineVector.dy
        )
        
        let deltaX = point.x - closestPointOnLine.x
        let deltaY = point.y - closestPointOnLine.y
        return hypot(deltaX, deltaY)
    }
}
