//
//  PhysicsEngine.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//

import os
import SwiftUI
import Foundation
import CoreGraphics

@available(iOS 16.0, *)
@available(watchOS 9.0, *)
public class PhysicsEngine {
    private static let logger = Logger.forCategory("physics")
    
    // NEW: Signposter for performance tracing
    #if DEBUG
    private static let signposter = OSSignposter(subsystem: "io.handcart.GraphEditor", category: "physics")
    #endif
    
    var simulationBounds: CGSize
    var stepCount: Int = 0
    private let maxNodesForQuadtree = 200
    private let symmetricFactor: CGFloat = 0.5
    internal var repulsionCalculator: RepulsionCalculator
    private var dampingBoostSteps: Int = 0
    internal var attractionCalculator: AttractionCalculator
    internal var centeringCalculator: CenteringCalculator
    internal var positionUpdater: PositionUpdater
    public var layoutMode: LayoutMode = .network
    public var alpha: CGFloat = 1.0  // New: Cooling parameter
    public var damping: CGFloat = 0.95  // NEW: Scale velocities each step for smooth settling
    private var cachedDepths: [NodeID: Int] = [:]  // Cache depth calculations
    private var lastDepthUpdateStep: Int = 0
        
        public init(simulationBounds: CGSize, layoutMode: LayoutMode = .network) {
            self.simulationBounds = simulationBounds
            self.layoutMode = layoutMode
            self.repulsionCalculator = RepulsionCalculator(maxNodesForQuadtree: 200, simulationBounds: simulationBounds)
            // Use asymmetric attraction and preferred angles for hierarchy mode
            let useAsymmetric = (layoutMode == .hierarchy)
            let usePreferredAngles = (layoutMode == .hierarchy)
            self.attractionCalculator = AttractionCalculator(symmetricFactor: self.symmetricFactor, useAsymmetric: useAsymmetric, usePreferredAngles: usePreferredAngles)
            self.centeringCalculator = CenteringCalculator(simulationBounds: simulationBounds)
            self.positionUpdater = PositionUpdater(simulationBounds: simulationBounds)
        }
    
    public func temporaryDampingBoost(steps: Int = 20) {
        dampingBoostSteps = steps
    }
    
    public func updateLayoutMode(_ mode: LayoutMode) {
        guard mode != layoutMode else { return }
        Self.logger.info("Layout mode changed: \(String(describing: self.layoutMode)) -> \(String(describing: mode))")
        layoutMode = mode
        // Update attraction calculator for new mode
        let useAsymmetric = (mode == .hierarchy)
        let usePreferredAngles = (mode == .hierarchy)
        attractionCalculator = AttractionCalculator(symmetricFactor: self.symmetricFactor, useAsymmetric: useAsymmetric, usePreferredAngles: usePreferredAngles)
        // Clear depth cache when mode changes
        cachedDepths.removeAll()
        lastDepthUpdateStep = 0
    }

    /// Updates simulation bounds to accommodate hierarchy depth
    /// Only affects vertical dimension; horizontal stays at screen width
    public func updateSimulationBounds(_ newBounds: CGSize) {
        guard newBounds != simulationBounds else { return }
        if LogManager.verboseSimulationLogging {
            Self.logger.debug("Simulation bounds updated: \(String(format: "%.0fx%.0f", self.simulationBounds.width, self.simulationBounds.height)) -> \(String(format: "%.0fx%.0f", newBounds.width, newBounds.height))")
        }
        simulationBounds = newBounds
        // Recreate calculators with new bounds since they store bounds internally
        centeringCalculator = CenteringCalculator(simulationBounds: newBounds)
        positionUpdater = PositionUpdater(simulationBounds: newBounds)
        repulsionCalculator = RepulsionCalculator(maxNodesForQuadtree: maxNodesForQuadtree, simulationBounds: newBounds)
    }
     
    private var simulationSteps = 0
    
    public func resetSimulation() {
        simulationSteps = 0
        stepCount = 0
        alpha = 1.0  // New: Reset alpha
    }
    
    public var isPaused: Bool = false
    
    @discardableResult
    public func simulationStep(nodes: [any NodeProtocol], edges: [GraphEdge], fixedIDs: Set<NodeID>? = nil, segmentConfigs: [NodeID: SegmentConfig] = [:]) -> ([any NodeProtocol], Bool) {
        if isPaused || stepCount > Constants.Physics.maxSimulationSteps { return (nodes, false) }
        stepCount += 1
        
        if stepCount == 1 && LogManager.verboseSimulationLogging {
            Self.logger.debug("First simulation step with layoutMode=\(String(describing: self.layoutMode)), nodes=\(nodes.count), edges=\(edges.count)")
        }
        
        #if DEBUG
        let stepState = Self.signposter.beginInterval("SimulationStep", "Step \(self.stepCount), Nodes: \(nodes.count), Edges: \(edges.count)")
        #endif
        
        // CRITICAL: Store original positions for fixed nodes BEFORE physics runs
        // This prevents fixed nodes from moving due to residual velocity or forces
        var originalPositions: [NodeID: CGPoint] = [:]
        if let fixed = fixedIDs {
            for node in nodes where fixed.contains(node.id) {
                originalPositions[node.id] = node.position
            }
        }
        
        let (forces, quadtree) = computeRepulsions(nodes: nodes)
        var updatedForces = applyAttractions(forces: forces, edges: edges, nodes: nodes)
        updatedForces = applyCentering(forces: updatedForces, nodes: nodes, layoutMode: layoutMode, edges: edges, segmentConfigs: segmentConfigs)

        // Apply layer forces in hierarchy mode
        if layoutMode == .hierarchy {
            // Update depth cache every 10 steps or when starting
            if stepCount - lastDepthUpdateStep > 10 || cachedDepths.isEmpty {
                cachedDepths = HierarchyLayoutHelper.calculateDepths(nodes: nodes, edges: edges)
                lastDepthUpdateStep = stepCount
                let maxDepth = cachedDepths.values.max() ?? 0
                if LogManager.verboseSimulationLogging {
                    Self.logger.debug("Hierarchical layout: calculated depths for \(self.cachedDepths.count) nodes, maxDepth=\(maxDepth)")
                }

                // Check if we need to expand bounds vertically to accommodate hierarchy
                // For deep hierarchies (10+), use aggressive expansion to maintain 40pt spacing
                let targetSpacing: CGFloat = maxDepth >= 10 ? 40 : 35
                if let requiredHeight = HierarchyLayoutHelper.calculateRequiredVerticalBounds(
                    maxDepth: maxDepth,
                    currentBounds: simulationBounds,
                    minSpacing: targetSpacing
                ) {
                    let screenWidth = simulationBounds.width
                    let newBounds = CGSize(width: screenWidth, height: requiredHeight)
                    updateSimulationBounds(newBounds)
                    if LogManager.verboseSimulationLogging {
                        Self.logger.info("Expanded simulation bounds vertically to accommodate depth \(maxDepth): height \(String(format: "%.0f", requiredHeight)) with \(String(format: "%.0f", targetSpacing))pt spacing")
                    }
                }
            }
            updatedForces = HierarchyLayoutHelper.applyLayerForces(
                forces: updatedForces,
                nodes: nodes,
                depths: cachedDepths,
                simulationBounds: simulationBounds
            )
        }
        
        // Apply directional layout forces for configured segments
        if !segmentConfigs.isEmpty {
            updatedForces = DirectionalLayoutCalculator.applyDirectionalForces(
                forces: updatedForces,
                nodes: nodes,
                edges: edges,
                segmentConfigs: segmentConfigs,
                simulationBounds: simulationBounds
            )
        }

        updatedForces = scaleForcesByAlpha(forces: updatedForces)
        
        // NEW: Skip forces for fixed nodes (set to .zero)
        if let fixed = fixedIDs {
            for id in fixed {
                updatedForces[id] = .zero
            }
        }
        
        let (tempNodes, isActive) = positionUpdater.updatePositionsAndVelocities(nodes: nodes, forces: updatedForces, edges: edges, quadtree: quadtree, damping: self.damping)
        
        // NEW: For fixed nodes, enforce position/velocity in post-processing
        let updatedNodes = postProcessNodes(tempNodes: tempNodes, isActive: isActive, fixedIDs: fixedIDs, originalPositions: originalPositions)
        
        logVelocityIfNeeded(nodes: updatedNodes)

        alpha = max(alpha * 0.994, 0.04)
        
#if DEBUG
        Self.signposter.endInterval("SimulationStep", stepState, "Active: \(isActive)")
        #endif
        
        // In updatePositions (or at the end of simulationStep)
        _ = updatedNodes.map { node in
            var dampedNode = node
            dampedNode.velocity *= damping
            return dampedNode
        }
        // Then use dampedNodes for the return
        
        return (updatedNodes, isActive)
    }
    
    private func computeRepulsions(nodes: [any NodeProtocol]) -> ([NodeID: CGPoint], Quadtree?) {
        #if DEBUG
        let repulsionState = Self.signposter.beginInterval("RepulsionCalculation")
        #endif
        let result = repulsionCalculator.computeRepulsions(nodes: nodes, layoutMode: layoutMode)
        #if DEBUG
        Self.signposter.endInterval("RepulsionCalculation", repulsionState)
        #endif
        return result
    }
    
    private func applyAttractions(forces: [NodeID: CGPoint], edges: [GraphEdge], nodes: [any NodeProtocol]) -> [NodeID: CGPoint] {
        #if DEBUG
        let attractionState = Self.signposter.beginInterval("AttractionCalculation")
        #endif
        let result = attractionCalculator.applyAttractions(forces: forces, edges: edges, nodes: nodes)
        #if DEBUG
        Self.signposter.endInterval("AttractionCalculation", attractionState)
        #endif
        return result
    }
    
    private func applyCentering(forces: [NodeID: CGPoint], nodes: [any NodeProtocol], layoutMode: LayoutMode, edges: [GraphEdge], segmentConfigs: [NodeID: SegmentConfig]) -> [NodeID: CGPoint] {
        #if DEBUG
        let centeringState = Self.signposter.beginInterval("CenteringCalculation")
        #endif
        let result = centeringCalculator.applyCentering(forces: forces, nodes: nodes, layoutMode: layoutMode, edges: edges, segmentConfigs: segmentConfigs)
        #if DEBUG
        Self.signposter.endInterval("CenteringCalculation", centeringState)
        #endif
        return result
    }
    
    private func scaleForcesByAlpha(forces: [NodeID: CGPoint]) -> [NodeID: CGPoint] {
        #if DEBUG
        let scalingState = Self.signposter.beginInterval("ForceScaling")
        #endif
        let result = forces.mapValues { $0 * alpha }
        #if DEBUG
        Self.signposter.endInterval("ForceScaling", scalingState)
        #endif
        return result
    }
    
    private func updatePositions(nodes: [any NodeProtocol], forces: [NodeID: CGPoint], edges: [GraphEdge], quadtree: Quadtree?) -> ([any NodeProtocol], Bool) {
        #if DEBUG
        let updateState = Self.signposter.beginInterval("PositionUpdate")
        #endif
        let result = positionUpdater.updatePositionsAndVelocities(nodes: nodes, forces: forces, edges: edges, quadtree: quadtree, damping: damping)
        if dampingBoostSteps > 0 { dampingBoostSteps -= 1 }
        #if DEBUG
        Self.signposter.endInterval("PositionUpdate", updateState)
        #endif
        return result
    }
    
    private func postProcessNodes(tempNodes: [any NodeProtocol], isActive: Bool, fixedIDs: Set<NodeID>? = nil, originalPositions: [NodeID: CGPoint] = [:]) -> [any NodeProtocol] {
        #if DEBUG
        let postState = Self.signposter.beginInterval("PostProcessing")
        #endif
        
        let result = tempNodes.map { node in
            if let fixed = fixedIDs, fixed.contains(node.id) {
                // CRITICAL: Restore ORIGINAL position from before physics step, zero velocity
                // This prevents fixed nodes from moving due to residual velocity
                if let originalPos = originalPositions[node.id] {
                    return node.with(position: originalPos, velocity: .zero)
                } else {
                    // Fallback: keep current position if original not found
                    return node.with(position: node.position, velocity: .zero)
                }
            }
            return node
        }
        
        #if DEBUG
        Self.signposter.endInterval("PostProcessing", postState)
        #endif
        return result
    }
    
    private func logVelocityIfNeeded(nodes: [any NodeProtocol]) {
        if LogManager.verboseSimulationLogging && stepCount % 10 == 0 {  // Reduced logging frequency
            let totalVel = nodes.reduce(0.0) { $0 + $1.velocity.magnitude }
            Self.logger.debugLog("Step \(stepCount): Total velocity = \(String(format: "%.2f", totalVel)), alpha = \(String(format: "%.3f", alpha))")

            // Extra logging for hierarchical mode to debug positioning
            if layoutMode == .hierarchy && stepCount % 50 == 0 {
                Self.logger.debug("Node positions at step \(self.stepCount):")
                for node in nodes.prefix(5) {  // Only log first 5 nodes
                    let depth = self.cachedDepths[node.id] ?? -1
                    Self.logger.debug("  Node \(node.id): pos=(\(String(format: "%.1f", node.position.x)), \(String(format: "%.1f", node.position.y))), vel=\(String(format: "%.2f", node.velocity.magnitude)), depth=\(depth)")
                }
            }

            #if DEBUG
            Self.signposter.emitEvent("VelocityCheck", "Step \(self.stepCount): Total velocity = \(totalVel)")
            #endif
        }
    }
    
    // Add to PhysicsEngine class
    public func runSimulation(steps: Int, nodes: [any NodeProtocol], edges: [GraphEdge], fixedIDs: Set<NodeID>? = nil) -> [any NodeProtocol] {
        #if DEBUG
        let runState = Self.signposter.beginInterval("RunSimulation", "Steps: \(steps), Nodes: \(nodes.count)")
        #endif
        var currentNodes = nodes
        for _ in 0..<steps {
            let (updatedNodes, isActive) = simulationStep(nodes: currentNodes, edges: edges, fixedIDs: fixedIDs)
            currentNodes = updatedNodes
            if !isActive { break }  // Early exit if stable
        }
        #if DEBUG
        Self.signposter.endInterval("RunSimulation", runState)
        #endif
        return currentNodes
    }
    
    public func boundingBox(nodes: [any NodeProtocol]) -> CGRect {
        #if DEBUG
        let state = Self.signposter.beginInterval("BoundingBoxCalculation", "Nodes: \(nodes.count)")
        defer { Self.signposter.endInterval("BoundingBoxCalculation", state) }
        #endif

        return computeBoundingBox(for: nodes)  // Reuse shared func
    }
    
    public func centerNodes(nodes: [any NodeProtocol], around center: CGPoint? = nil) -> [any NodeProtocol] {
        #if DEBUG
        let state = Self.signposter.beginInterval("CenterNodes", "Nodes: \(nodes.count)")
        defer { Self.signposter.endInterval("CenterNodes", state) }
        #endif
        guard !nodes.isEmpty else { return [] }
        let targetCenter = center ?? CGPoint(x: simulationBounds.width / 2, y: simulationBounds.height / 2)
        
        // Compute current centroid
        let totalX = nodes.reduce(0.0) { $0 + $1.position.x }
        let totalY = nodes.reduce(0.0) { $0 + $1.position.y }
        let centroid = CGPoint(x: totalX / CGFloat(nodes.count), y: totalY / CGFloat(nodes.count))
        
        // Create updated nodes with translation
        let deltaX = targetCenter.x - centroid.x
        let deltaY = targetCenter.y - centroid.y
        return nodes.map { node in
            let newPosition = CGPoint(x: node.position.x + deltaX, y: node.position.y + deltaY)
            return node.with(position: newPosition, velocity: node.velocity)
        }
    }
    
    public func queryNearby(position: CGPoint, radius: CGFloat, nodes: [any NodeProtocol]) -> [any NodeProtocol] {
        #if DEBUG
        let state = Self.signposter.beginInterval("QueryNearby", "Position: (\(position.x), \(position.y)), Radius: \(radius), Nodes: \(nodes.count)")
        defer { Self.signposter.endInterval("QueryNearby", state) }
        #endif
        guard !nodes.isEmpty else { return [] }
        let quadtree = repulsionCalculator.buildQuadtree(nodes: nodes)
        return quadtree.queryNearby(position: position, radius: radius)
    }
}
