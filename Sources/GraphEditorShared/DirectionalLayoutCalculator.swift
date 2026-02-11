//
//  DirectionalLayoutCalculator.swift
//  GraphEditorShared
//
//  Applies directional layout forces to graph segments
//  Similar to HierarchyLayoutHelper but for horizontal/vertical arrangements
//

import Foundation
import CoreGraphics
import os.log

@available(iOS 16.0, watchOS 9.0, *)
public struct DirectionalLayoutCalculator {
    private static let logger = Logger(subsystem: "GraphEditorShared", category: "directional-layout")
    
    // MARK: - Segment Node Discovery
    
    /// Build a map of which nodes belong to which segment
    public static func buildSegmentMembership(
        nodes: [any NodeProtocol],
        edges: [GraphEdge],
        segmentConfigs: [NodeID: SegmentConfig]
    ) -> [NodeID: NodeID] {  // nodeID -> rootNodeID
        var membership: [NodeID: NodeID] = [:]
        
        // Build adjacency map for hierarchy edges
        var childrenMap: [NodeID: [NodeID]] = [:]
        for edge in edges where edge.type == .hierarchy {
            childrenMap[edge.from, default: []].append(edge.target)
        }
        
        // For each segment root, traverse and mark all descendants
        for (rootID, _) in segmentConfigs {
            var queue = [rootID]
            var visited = Set<NodeID>([rootID])
            membership[rootID] = rootID  // Root belongs to its own segment
            
            while !queue.isEmpty {
                let currentID = queue.removeFirst()
                
                if let children = childrenMap[currentID] {
                    for childID in children {
                        guard !visited.contains(childID) else { continue }
                        visited.insert(childID)
                        membership[childID] = rootID  // Mark child as belonging to this segment
                        queue.append(childID)
                    }
                }
            }
        }
        
        return membership
    }
    
    // MARK: - Directional Force Application
    
    /// Apply directional layout forces to segment nodes
    /// - Horizontal: Constrains X positions based on hierarchy depth
    /// - Vertical: Constrains Y positions based on hierarchy depth (similar to layer forces)
    public static func applyDirectionalForces(
        forces: [NodeID: CGPoint],
        nodes: [any NodeProtocol],
        edges: [GraphEdge],
        segmentConfigs: [NodeID: SegmentConfig],
        simulationBounds: CGSize
    ) -> [NodeID: CGPoint] {
        guard !segmentConfigs.isEmpty else { return forces }
        
        if LogManager.verboseSimulationLogging {
            logger.debug("Applying directional forces for \(segmentConfigs.count) segments")
        }
        
        var updatedForces = forces
        
        // Build segment membership map
        let membership = buildSegmentMembership(
            nodes: nodes,
            edges: edges,
            segmentConfigs: segmentConfigs
        )
        
        // Calculate depths within each segment
        let depths = calculateSegmentDepths(
            nodes: nodes,
            edges: edges,
            segmentConfigs: segmentConfigs,
            membership: membership
        )
        
        // Apply forces for each segment
        for (rootID, config) in segmentConfigs {
            if LogManager.verboseSimulationLogging {
                let segmentNodeCount = nodes.filter { membership[$0.id] == rootID }.count
                logger.debug("Segment \(rootID.uuidString.prefix(8)): direction=\(config.direction.rawValue), nodes=\(segmentNodeCount)")
            }
            
            applySegmentForces(
                forces: &updatedForces,
                nodes: nodes,
                depths: depths,
                rootID: rootID,
                config: config,
                membership: membership,
                simulationBounds: simulationBounds
            )
        }
        
        return updatedForces
    }
    
    // MARK: - Depth Calculation
    
    /// Calculate depth from root for all nodes in all segments
    private static func calculateSegmentDepths(
        nodes: [any NodeProtocol],
        edges: [GraphEdge],
        segmentConfigs: [NodeID: SegmentConfig],
        membership: [NodeID: NodeID]
    ) -> [NodeID: Int] {
        var depths: [NodeID: Int] = [:]
        
        // Build hierarchy adjacency map
        var childrenMap: [NodeID: [NodeID]] = [:]
        for edge in edges where edge.type == .hierarchy {
            childrenMap[edge.from, default: []].append(edge.target)
        }
        
        // BFS from each segment root
        for (rootID, _) in segmentConfigs {
            var queue: [(NodeID, Int)] = [(rootID, 0)]
            var visited = Set<NodeID>([rootID])
            depths[rootID] = 0
            
            while !queue.isEmpty {
                let (currentID, depth) = queue.removeFirst()
                
                if let children = childrenMap[currentID] {
                    for childID in children {
                        // Only traverse nodes in this segment
                        guard membership[childID] == rootID else { continue }
                        guard !visited.contains(childID) else { continue }
                        
                        visited.insert(childID)
                        depths[childID] = depth + 1
                        queue.append((childID, depth + 1))
                    }
                }
            }
        }
        
        return depths
    }
    
    // MARK: - Force Application
    
    /// Apply directional forces for a single segment
    private static func applySegmentForces(
        forces: inout [NodeID: CGPoint],
        nodes: [any NodeProtocol],
        depths: [NodeID: Int],
        rootID: NodeID,
        config: SegmentConfig,
        membership: [NodeID: NodeID],
        simulationBounds: CGSize
    ) {
        // Get all nodes in this segment
        let segmentNodes = nodes.filter { membership[$0.id] == rootID }
        guard !segmentNodes.isEmpty else { return }
        
        // Find max depth for dynamic spacing
        let maxDepth = segmentNodes.compactMap { depths[$0.id] }.max() ?? 0
        
        // Calculate dynamic spacing
        let spacing = calculateDynamicSpacing(
            maxDepth: maxDepth,
            preferredSpacing: config.nodeSpacing,
            direction: config.direction,
            simulationBounds: simulationBounds
        )
        
        // Calculate anchor position (where depth 0 should be)
        let anchor = calculateAnchorPosition(
            segmentNodes: segmentNodes,
            direction: config.direction,
            spacing: spacing,
            maxDepth: maxDepth,
            simulationBounds: simulationBounds,
            depths: depths
        )
        
        // Calculate alignment target (average position on the unconstrained axis)
        // This keeps all nodes aligned on a straight line
        let alignmentTarget: CGFloat
        switch config.direction {
        case .horizontal:
            // For horizontal layout, align all nodes to the same Y position
            alignmentTarget = segmentNodes.map { $0.position.y }.reduce(0, +) / CGFloat(segmentNodes.count)
        case .vertical:
            // For vertical layout, align all nodes to the same X position
            alignmentTarget = segmentNodes.map { $0.position.x }.reduce(0, +) / CGFloat(segmentNodes.count)
        }
        
        // Apply forces along both axes
        for node in segmentNodes {
            guard let depth = depths[node.id] else { continue }
            
            let targetDepthPosition = anchor + CGFloat(depth) * spacing
            let currentForce = forces[node.id] ?? .zero
            
            switch config.direction {
            case .horizontal:
                // Constrain X based on depth, align Y to common line
                let forceX = (targetDepthPosition - node.position.x) * config.effectiveStiffness
                let forceY = (alignmentTarget - node.position.y) * config.effectiveStiffness
                
                if LogManager.verboseSimulationLogging && (abs(forceX) > 1.0 || abs(forceY) > 1.0) {
                    logger.debug("  Node depth=\(depth): currentPos=(\(String(format: "%.1f", node.position.x)),\(String(format: "%.1f", node.position.y))), targetPos=(\(String(format: "%.1f", targetDepthPosition)),\(String(format: "%.1f", alignmentTarget))), force=(\(String(format: "%.1f", forceX)),\(String(format: "%.1f", forceY)))")
                }
                
                forces[node.id] = CGPoint(
                    x: currentForce.x + forceX,
                    y: currentForce.y + forceY
                )
                
            case .vertical:
                // Constrain Y based on depth, align X to common line
                let forceX = (alignmentTarget - node.position.x) * config.effectiveStiffness
                let forceY = (targetDepthPosition - node.position.y) * config.effectiveStiffness
                
                forces[node.id] = CGPoint(
                    x: currentForce.x + forceX,
                    y: currentForce.y + forceY
                )
            }
        }
    }
    
    /// Calculate dynamic spacing that fits within bounds
    private static func calculateDynamicSpacing(
        maxDepth: Int,
        preferredSpacing: CGFloat,
        direction: LayoutDirection,
        simulationBounds: CGSize
    ) -> CGFloat {
        guard maxDepth > 0 else { return preferredSpacing }
        
        // Calculate total space needed
        let totalNeeded = CGFloat(maxDepth) * preferredSpacing
        
        // Determine available space based on direction
        let availableSpace: CGFloat
        switch direction {
        case .horizontal:
            availableSpace = simulationBounds.width * 0.8  // Use 80% of width
        case .vertical:
            availableSpace = simulationBounds.height * 0.8  // Use 80% of height
        }
        
        // If we need more space than available, compress
        if totalNeeded > availableSpace {
            return availableSpace / CGFloat(maxDepth)
        }
        
        return preferredSpacing
    }
    
    /// Calculate anchor position (where depth 0 nodes should be positioned)
    /// Centers the entire segment within simulation bounds for optimal layout
    private static func calculateAnchorPosition(
        segmentNodes: [any NodeProtocol],
        direction: LayoutDirection,
        spacing: CGFloat,
        maxDepth: Int,
        simulationBounds: CGSize,
        depths: [NodeID: Int]
    ) -> CGFloat {
        // Calculate total extent of the segment
        let totalExtent = CGFloat(maxDepth) * spacing

        switch direction {
        case .horizontal:
            // For horizontal layout, center the segment within available width
            // Leave margin for node radius and comfort
            let margin: CGFloat = 20.0
            let availableWidth = simulationBounds.width - (2 * margin)

            if totalExtent < availableWidth {
                // Segment fits comfortably - center it
                return margin + (availableWidth - totalExtent) / 2.0
            } else {
                // Segment is wide - start from margin
                return margin
            }

        case .vertical:
            // For vertical layout, center the segment within available height
            let margin: CGFloat = 20.0
            let availableHeight = simulationBounds.height - (2 * margin)

            if totalExtent < availableHeight {
                // Segment fits comfortably - center it
                return margin + (availableHeight - totalExtent) / 2.0
            } else {
                // Segment is tall - start from margin
                return margin
            }
        }
    }
}
