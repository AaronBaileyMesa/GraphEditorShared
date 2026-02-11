//
//  HierarchyLayoutHelper.swift
//  GraphEditorShared
//
//  Utilities for calculating hierarchy depth and applying layered layout forces
//

import Foundation
import CoreGraphics
import OSLog

@available(iOS 16.0, watchOS 9.0, *)
public struct HierarchyLayoutHelper {
    private static let logger = Logger(subsystem: "com.grapheditor.shared", category: "HierarchyLayout")

    /// Calculates the hierarchy depth for each node based on parent-child relationships
    /// Depth 0 = root nodes (no incoming hierarchy edges)
    /// Depth N = longest path from any root
    /// Control nodes are excluded from hierarchy calculations (they're ephemeral UI elements)
    public static func calculateDepths(nodes: [any NodeProtocol], edges: [GraphEdge]) -> [NodeID: Int] {
        var depths: [NodeID: Int] = [:]

        // Filter out control nodes - they're ephemeral UI elements, not part of the graph hierarchy
        let graphNodes = nodes.filter { node in
            node.fullyUnwrapped() is ControlNode == false
        }

        // Build adjacency list of hierarchy edges (parent -> children)
        var children: [NodeID: [NodeID]] = [:]
        var hasParent: Set<NodeID> = []

        for edge in edges where edge.type == .hierarchy {
            children[edge.from, default: []].append(edge.target)
            hasParent.insert(edge.target)
        }

        // Find root nodes (nodes with no incoming hierarchy edges)
        let roots = graphNodes.filter { !hasParent.contains($0.id) }.map { $0.id }

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

        // Assign depth 0 to any orphaned nodes (excluding control nodes)
        for node in graphNodes where depths[node.id] == nil {
            depths[node.id] = 0
        }

        return depths
    }

    /// Applies Y-constraint forces to pull nodes toward their target layer
    /// Uses dynamic layer spacing and vertical centering for deep hierarchies
    /// Target Y = baseY + depth * dynamicSpacing
    /// Horizontal positioning relies on physics forces (repulsion, attraction) only
    public static func applyLayerForces(
        forces: [NodeID: CGPoint],
        nodes: [any NodeProtocol],
        depths: [NodeID: Int],
        simulationBounds: CGSize
    ) -> [NodeID: CGPoint] {
        var updatedForces = forces

        // Find maximum depth in the hierarchy
        let maxDepth = depths.values.max() ?? 0
        
        // Calculate dynamic layer spacing to fit within bounds
        let dynamicSpacing = calculateDynamicSpacing(
            maxDepth: maxDepth,
            simulationBounds: simulationBounds
        )
        
        // Calculate base Y to vertically center the hierarchy
        let baseY = calculateCenteredBaseY(
            maxDepth: maxDepth,
            layerSpacing: dynamicSpacing,
            simulationBounds: simulationBounds
        )
        
        // Debug logging for first few nodes
        var totalLayerForce: CGFloat = 0
        var nodesLogged = 0
        
        for node in nodes {
            // Skip control nodes - they shouldn't be affected by hierarchical layout
            if node.fullyUnwrapped() is ControlNode {
                continue
            }
            
            guard let depth = depths[node.id] else { continue }

            // Calculate target Y position for this depth
            let targetY = baseY + CGFloat(depth) * dynamicSpacing

            // Calculate force toward target Y
            let deltaY = targetY - node.position.y
            let layerForce = deltaY * Constants.Physics.layerStiffness
            totalLayerForce += abs(layerForce)
            
            // Log first few nodes to see what's happening (only when verbose logging is enabled)
            if LogManager.verboseSimulationLogging && nodesLogged < 3 {
                logger.debug("Node \(node.id): currentY=\(String(format: "%.1f", node.position.y)), targetY=\(String(format: "%.1f", targetY)), deltaY=\(String(format: "%.1f", deltaY)), currentX=\(String(format: "%.1f", node.position.x)), depth=\(depth)")
                nodesLogged += 1
            }

            // Apply only Y force (horizontal spacing comes from physics)
            let currentForce = updatedForces[node.id] ?? .zero
            updatedForces[node.id] = CGPoint(
                x: currentForce.x,
                y: currentForce.y + layerForce
            )
        }
        
        if LogManager.verboseSimulationLogging {
            logger.debug("Hierarchy: maxDepth=\(maxDepth), spacing=\(String(format: "%.1f", dynamicSpacing)), baseY=\(String(format: "%.1f", baseY)), totalLayerForce=\(String(format: "%.2f", totalLayerForce))")
        }

        return updatedForces
    }
    
    /// Calculates dynamic layer spacing based on hierarchy depth and available space
    /// Returns smaller spacing for deep hierarchies to keep all nodes visible
    /// For very deep hierarchies (10+ levels), uses more aggressive expansion
    private static func calculateDynamicSpacing(
        maxDepth: Int,
        simulationBounds: CGSize
    ) -> CGFloat {
        guard maxDepth > 0 else { return Constants.Physics.layerSpacing }
        
        // For deep hierarchies (10+ levels), prefer expansion over compression
        let targetSpacing: CGFloat = maxDepth >= 10 ? 40 : 50  // Target spacing for deep hierarchies
        let minSpacing: CGFloat = 25  // Increased from 15 - absolute minimum for readability
        let maxSpacing = Constants.Physics.layerSpacing  // Default spacing (60)
        
        // Reserve margins at top and bottom (15% each for deep hierarchies, 20% otherwise)
        let marginPercent: CGFloat = maxDepth >= 10 ? 0.15 : 0.2
        let availableHeight = simulationBounds.height * (1.0 - 2 * marginPercent)
        
        // Calculate spacing needed to fit all layers
        let requiredSpacing = availableHeight / CGFloat(maxDepth)
        
        // If we can't fit with target spacing, we need bounds expansion (handled by caller)
        if requiredSpacing < targetSpacing {
            return max(minSpacing, requiredSpacing)
        }
        
        // Otherwise use the best spacing that fits
        return min(maxSpacing, requiredSpacing)
    }
    
    /// Calculates base Y position to vertically center the hierarchy
    /// For shallow hierarchies, uses top-aligned layout (20% from top)
    /// For deep hierarchies, centers to keep all nodes visible
    private static func calculateCenteredBaseY(
        maxDepth: Int,
        layerSpacing: CGFloat,
        simulationBounds: CGSize
    ) -> CGFloat {
        guard maxDepth > 0 else { return simulationBounds.height * 0.2 }
        
        // Total height required for the hierarchy
        let totalHierarchyHeight = CGFloat(maxDepth) * layerSpacing
        
        // If hierarchy fits comfortably with top alignment, use it
        let topAlignedBaseY = simulationBounds.height * 0.2
        let topAlignedBottomY = topAlignedBaseY + totalHierarchyHeight
        
        if topAlignedBottomY <= simulationBounds.height * 0.8 {
            // Hierarchy fits with top alignment
            return topAlignedBaseY
        } else {
            // Center the hierarchy vertically
            return (simulationBounds.height - totalHierarchyHeight) / 2
        }
    }
    
    /// Calculates the minimum vertical bounds needed to fit the hierarchy with reasonable spacing
    /// Returns the required height, or nil if current bounds are sufficient
    /// For deep hierarchies (10+ levels), uses more aggressive expansion to maintain readability
    public static func calculateRequiredVerticalBounds(
        maxDepth: Int,
        currentBounds: CGSize,
        minSpacing: CGFloat = 30  // Minimum acceptable spacing between layers
    ) -> CGFloat? {
        guard maxDepth > 0 else { return nil }

        // For deep hierarchies, use more aggressive target spacing
        let targetSpacing: CGFloat = maxDepth >= 10 ? 40 : minSpacing
        
        // Use smaller margins for deep hierarchies to maximize usable space
        let marginPercent: CGFloat = maxDepth >= 10 ? 0.15 : 0.2
        let topMargin = currentBounds.width * marginPercent  // Use width as reference for consistent margins
        let bottomMargin = currentBounds.width * marginPercent
        
        let totalHierarchyHeight = CGFloat(maxDepth) * targetSpacing
        let requiredHeight = topMargin + totalHierarchyHeight + bottomMargin

        // Only expand if needed
        if requiredHeight > currentBounds.height {
            return requiredHeight
        }
        return nil
    }

    /// Validates that the hierarchical layout will keep all nodes within bounds
    /// Returns true if all target Y positions are within the simulation bounds
    public static func validateLayoutBounds(
        depths: [NodeID: Int],
        simulationBounds: CGSize
    ) -> Bool {
        guard !depths.isEmpty else { return true }

        let maxDepth = depths.values.max() ?? 0
        let dynamicSpacing = calculateDynamicSpacing(
            maxDepth: maxDepth,
            simulationBounds: simulationBounds
        )
        let baseY = calculateCenteredBaseY(
            maxDepth: maxDepth,
            layerSpacing: dynamicSpacing,
            simulationBounds: simulationBounds
        )

        // Check that all target Y positions are within bounds
        for depth in 0...maxDepth {
            let targetY = baseY + CGFloat(depth) * dynamicSpacing
            if targetY < 0 || targetY > simulationBounds.height {
                return false
            }
        }
        
        return true
    }
}
