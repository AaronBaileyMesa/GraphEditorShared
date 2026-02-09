//
//  HierarchyLayoutHelper.swift
//  GraphEditorShared
//
//  Utilities for calculating hierarchy depth and applying layered layout forces
//

import Foundation
import CoreGraphics

@available(iOS 16.0, watchOS 9.0, *)
public struct HierarchyLayoutHelper {

    /// Calculates the hierarchy depth for each node based on parent-child relationships
    /// Depth 0 = root nodes (no incoming hierarchy edges)
    /// Depth N = longest path from any root
    public static func calculateDepths(nodes: [any NodeProtocol], edges: [GraphEdge]) -> [NodeID: Int] {
        var depths: [NodeID: Int] = [:]

        // Build adjacency list of hierarchy edges (parent -> children)
        var children: [NodeID: [NodeID]] = [:]
        var hasParent: Set<NodeID> = []

        for edge in edges where edge.type == .hierarchy {
            children[edge.from, default: []].append(edge.target)
            hasParent.insert(edge.target)
        }

        // Find root nodes (nodes with no incoming hierarchy edges)
        let roots = nodes.filter { !hasParent.contains($0.id) }.map { $0.id }

        // BFS to assign depths
        var queue: [(NodeID, Int)] = roots.map { ($0, 0) }
        var visited: Set<NodeID> = []

        while !queue.isEmpty {
            let (currentID, currentDepth) = queue.removeFirst()

            // Skip if already visited with a shorter or equal path
            if let existingDepth = depths[currentID], existingDepth >= currentDepth {
                continue
            }

            depths[currentID] = currentDepth
            visited.insert(currentID)

            // Add children to queue with depth + 1
            if let nodeChildren = children[currentID] {
                for childID in nodeChildren {
                    queue.append((childID, currentDepth + 1))
                }
            }
        }

        // Assign depth 0 to any orphaned nodes
        for node in nodes where depths[node.id] == nil {
            depths[node.id] = 0
        }

        return depths
    }

    /// Applies Y-constraint forces to pull nodes toward their target layer
    /// Target Y = depth * layerSpacing + baseY
    public static func applyLayerForces(
        forces: [NodeID: CGPoint],
        nodes: [any NodeProtocol],
        depths: [NodeID: Int],
        simulationBounds: CGSize
    ) -> [NodeID: CGPoint] {
        var updatedForces = forces

        // Base Y position (upper portion of bounds)
        let baseY = simulationBounds.height * 0.2

        for node in nodes {
            guard let depth = depths[node.id] else { continue }

            // Calculate target Y position for this depth
            let targetY = baseY + CGFloat(depth) * Constants.Physics.layerSpacing

            // Calculate force toward target Y
            let deltaY = targetY - node.position.y
            let layerForce = deltaY * Constants.Physics.layerStiffness

            // Apply only to Y component, preserve X forces
            let currentForce = updatedForces[node.id] ?? .zero
            updatedForces[node.id] = CGPoint(x: currentForce.x, y: currentForce.y + layerForce)
        }

        return updatedForces
    }
}
