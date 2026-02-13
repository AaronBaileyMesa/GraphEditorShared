//
//  CenteringCalculator.swift
//  GraphEditorShared
//
//  Created by handcart on 8/12/25.
//

import Foundation
import CoreGraphics

struct CenteringCalculator {
    let simulationBounds: CGSize

    @available(iOS 16.0, *)
    func applyCentering(forces: [NodeID: CGPoint], nodes: [any NodeProtocol], layoutMode: LayoutMode, edges: [GraphEdge] = [], segmentConfigs: [NodeID: SegmentConfig] = [:]) -> [NodeID: CGPoint] {
        var updatedForces = forces
        
        // Build segment membership if we have segment configs
        var segmentMembership: Set<NodeID> = []
        if !segmentConfigs.isEmpty {
            let membershipMap = DirectionalLayoutCalculator.buildSegmentMembership(
                nodes: nodes,
                edges: edges,
                segmentConfigs: segmentConfigs
            )
            segmentMembership = Set(membershipMap.keys)
            
            // Debug: Log segment membership details
            print("🧲 [CenteringCalculator] Segment configs: \(segmentConfigs.count)")
            print("🧲 [CenteringCalculator] Segment membership: \(segmentMembership.count) nodes")
            print("🧲 [CenteringCalculator] Total nodes: \(nodes.count)")
            print("🧲 [CenteringCalculator] Nodes NOT in segments: \(nodes.count - segmentMembership.count)")
            
            // Show which nodes are and aren't in segments
            for node in nodes {
                let isTable = node is TableNode
                let tableLabel = isTable ? " [TABLE]" : ""
                if segmentMembership.contains(node.id) {
                    print("  ✅ Node \(node.id.uuidString.prefix(8)) IN segment\(tableLabel)")
                } else if isTable {
                    print("  🚫 Node \(node.id.uuidString.prefix(8)) NOT in segment but IS TABLE - will be excluded from centering")
                } else {
                    print("  ❌ Node \(node.id.uuidString.prefix(8)) NOT in segment - will receive centering force")
                }
            }
        }
        
        // For hierarchy mode, apply gentle upward-left gravity instead of strong centering
        if layoutMode == .hierarchy {
            // Gentle gravity toward upper-left quadrant
            let targetPoint = CGPoint(x: simulationBounds.width * 0.3, y: simulationBounds.height * 0.3)
            let reducedForce = Constants.Physics.centeringForce * 0.3  // Much weaker than network mode
            
            for node in nodes {
                // Skip nodes that belong to a directionally-laid-out segment or are tables
                let isTable = node is TableNode
                let inSegment = segmentMembership.contains(node.id)

                if isTable {
                    #if DEBUG
                    print("🧲 [CenteringCalculator] Skipping table node \(node.id.uuidString.prefix(8)) - no centering force")
                    #endif
                }

                guard !inSegment && !isTable else { continue }

                let deltaX = targetPoint.x - node.position.x
                let deltaY = targetPoint.y - node.position.y
                let distToTarget = hypot(deltaX, deltaY)
                let forceX = deltaX * reducedForce * (1 + distToTarget / max(simulationBounds.width, simulationBounds.height))
                let forceY = deltaY * reducedForce * (1 + distToTarget / max(simulationBounds.width, simulationBounds.height))
                let currentForce = updatedForces[node.id] ?? .zero
                updatedForces[node.id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
            }
        } else {
            // Network mode: standard centering to middle
            let center = CGPoint(x: simulationBounds.width / 2, y: simulationBounds.height / 2)
            for node in nodes {
                // Skip nodes that belong to a directionally-laid-out segment or are tables
                let isTable = node is TableNode
                let inSegment = segmentMembership.contains(node.id)

                if isTable {
                    #if DEBUG
                    print("🧲 [CenteringCalculator] Skipping table node \(node.id.uuidString.prefix(8)) - no centering force")
                    #endif
                }

                guard !inSegment && !isTable else { continue }

                let deltaX = center.x - node.position.x
                let deltaY = center.y - node.position.y
                let distToCenter = hypot(deltaX, deltaY)
                let forceX = deltaX * Constants.Physics.centeringForce * (1 + distToCenter / max(simulationBounds.width, simulationBounds.height))
                let forceY = deltaY * Constants.Physics.centeringForce * (1 + distToCenter / max(simulationBounds.width, simulationBounds.height))
                let currentForce = updatedForces[node.id] ?? .zero
                updatedForces[node.id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
            }
        }
        return updatedForces
    }
}
