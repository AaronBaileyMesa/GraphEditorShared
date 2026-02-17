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
        
        // Build adjacency map for hierarchy and precedes edges
        // precedes edges allow decision trees to use directional layout
        var childrenMap: [NodeID: [NodeID]] = [:]
        for edge in edges where edge.type == .hierarchy || edge.type == .precedes {
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
        print("🔍 DirectionalLayout: Built membership map with \(membership.count) nodes")
        
        // Calculate depths within each segment
        let depths = calculateSegmentDepths(
            nodes: nodes,
            edges: edges,
            segmentConfigs: segmentConfigs,
            membership: membership
        )
        print("📏 DirectionalLayout: Calculated depths for \(depths.count) nodes")
        
        // Apply forces for each segment
        for (rootID, config) in segmentConfigs {
            let segmentNodeCount = nodes.filter { membership[$0.id] == rootID }.count
            print("🎨 DirectionalLayout: Segment \(rootID.uuidString.prefix(8)) - direction=\(config.direction.rawValue), nodes=\(segmentNodeCount)")
            if LogManager.verboseSimulationLogging {
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
        
        // Build hierarchy and precedes adjacency map
        // precedes edges allow decision trees to use directional layout
        var childrenMap: [NodeID: [NodeID]] = [:]
        for edge in edges where edge.type == .hierarchy || edge.type == .precedes {
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
    private static func applySegmentForces( // swiftlint:disable:this function_parameter_count function_body_length
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
        // Use the root node's actual position as the anchor to preserve initial positioning
        let anchor = calculateAnchorPosition(
            segmentNodes: segmentNodes,
            rootID: rootID,
            direction: config.direction,
            spacing: spacing,
            maxDepth: maxDepth,
            simulationBounds: simulationBounds,
            depths: depths
        )
        
        // Calculate alignment target (use root node's position as fixed reference)
        // This prevents the moving target problem where recalculating the average
        // every frame causes oscillation
        let alignmentTarget: CGFloat
        if let rootNode = segmentNodes.first(where: { $0.id == rootID }) {
            switch config.direction {
            case .horizontal:
                // For horizontal layout, align all nodes to root's Y position
                alignmentTarget = rootNode.position.y
                logger.debug("  Alignment target (root Y): \(String(format: "%.1f", alignmentTarget))")
            case .vertical:
                // For vertical layout, align all nodes to root's X position
                alignmentTarget = rootNode.position.x
                logger.debug("  Alignment target (root X): \(String(format: "%.1f", alignmentTarget))")
            }
        } else {
            // Fallback: use current average if root not found
            logger.debug("  WARNING: Root node not found in segment!")
            switch config.direction {
            case .horizontal:
                alignmentTarget = segmentNodes.map { $0.position.y }.reduce(0, +) / CGFloat(segmentNodes.count)
            case .vertical:
                alignmentTarget = segmentNodes.map { $0.position.x }.reduce(0, +) / CGFloat(segmentNodes.count)
            }
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
                
                if abs(forceX) > 1.0 || abs(forceY) > 1.0 {
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
                
                if abs(forceX) > 1.0 || abs(forceY) > 1.0 {
                    logger.debug("  Node depth=\(depth): currentPos=(\(String(format: "%.1f", node.position.x)),\(String(format: "%.1f", node.position.y))), targetPos=(\(String(format: "%.1f", alignmentTarget)),\(String(format: "%.1f", targetDepthPosition))), force=(\(String(format: "%.1f", forceX)),\(String(format: "%.1f", forceY)))")
                }
                
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
    /// Uses the root node's actual position to preserve initial layout intentions
    private static func calculateAnchorPosition( // swiftlint:disable:this function_parameter_count
        segmentNodes: [any NodeProtocol],
        rootID: NodeID,
        direction: LayoutDirection,
        spacing: CGFloat,
        maxDepth: Int,
        simulationBounds: CGSize,
        depths: [NodeID: Int]
    ) -> CGFloat {
        // Find the root node and use its position as the anchor
        // This preserves the initial positioning set by the template builder
        if let rootNode = segmentNodes.first(where: { $0.id == rootID }) {
            switch direction {
            case .horizontal:
                return rootNode.position.x
            case .vertical:
                return rootNode.position.y
            }
        }
        
        // Fallback: if root not found, center within simulation bounds
        let totalExtent = CGFloat(maxDepth) * spacing
        let margin: CGFloat = 20.0

        switch direction {
        case .horizontal:
            let availableWidth = simulationBounds.width - (2 * margin)
            if totalExtent < availableWidth {
                return margin + (availableWidth - totalExtent) / 2.0
            } else {
                return margin
            }

        case .vertical:
            let availableHeight = simulationBounds.height - (2 * margin)
            if totalExtent < availableHeight {
                return margin + (availableHeight - totalExtent) / 2.0
            } else {
                return margin
            }
        }
    }
}
