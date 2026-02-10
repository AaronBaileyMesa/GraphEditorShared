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
            simulationBounds: simulationBounds
        )
        
        // Apply forces along the constrained axis
        for node in segmentNodes {
            guard let depth = depths[node.id] else { continue }
            
            let targetPosition = anchor + CGFloat(depth) * spacing
            let currentPosition: CGFloat
            let forceAxis: CGFloat
            
            switch config.direction {
            case .horizontal:
                // Constrain X, leave Y free
                currentPosition = node.position.x
                forceAxis = (targetPosition - currentPosition) * config.effectiveStiffness
                
                let currentForce = forces[node.id] ?? .zero
                forces[node.id] = CGPoint(
                    x: currentForce.x + forceAxis,
                    y: currentForce.y
                )
                
            case .vertical:
                // Constrain Y, leave X free (like hierarchy layer forces)
                currentPosition = node.position.y
                forceAxis = (targetPosition - currentPosition) * config.effectiveStiffness
                
                let currentForce = forces[node.id] ?? .zero
                forces[node.id] = CGPoint(
                    x: currentForce.x,
                    y: currentForce.y + forceAxis
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
    private static func calculateAnchorPosition(
        segmentNodes: [any NodeProtocol],
        direction: LayoutDirection,
        spacing: CGFloat,
        maxDepth: Int,
        simulationBounds: CGSize
    ) -> CGFloat {
        // Calculate total extent of the segment
        let totalExtent = CGFloat(maxDepth) * spacing
        
        switch direction {
        case .horizontal:
            // Anchor to left with some margin, or center if it fits
            let margin: CGFloat = 50.0
            if totalExtent < simulationBounds.width * 0.6 {
                // Center horizontally if it fits comfortably
                return (simulationBounds.width - totalExtent) / 2.0
            } else {
                // Otherwise anchor to left margin
                return margin
            }
            
        case .vertical:
            // Anchor to top with some margin, or center if it fits
            let margin: CGFloat = 50.0
            if totalExtent < simulationBounds.height * 0.6 {
                // Center vertically if it fits comfortably
                return (simulationBounds.height - totalExtent) / 2.0
            } else {
                // Otherwise anchor to top margin
                return margin
            }
        }
    }
}
