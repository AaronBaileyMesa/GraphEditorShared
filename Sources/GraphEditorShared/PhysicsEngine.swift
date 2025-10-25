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
    private var stepCount: Int = 0
    private let maxNodesForQuadtree = 200
    private let symmetricFactor: CGFloat = 0.5
    internal let repulsionCalculator: RepulsionCalculator
    private var dampingBoostSteps: Int = 0
    internal let attractionCalculator: AttractionCalculator
    internal let centeringCalculator: CenteringCalculator
    internal let positionUpdater: PositionUpdater
    public var useAsymmetricAttraction: Bool = false
    public var alpha: CGFloat = 1.0  // New: Cooling parameter
    public var usePreferredAngles: Bool = false  // NEW: Toggle for angular forces (default off)
        
        public init(simulationBounds: CGSize) {
            self.simulationBounds = simulationBounds
            self.repulsionCalculator = RepulsionCalculator(maxNodesForQuadtree: 200, simulationBounds: simulationBounds)
            self.attractionCalculator = AttractionCalculator(symmetricFactor: self.symmetricFactor, useAsymmetric: useAsymmetricAttraction, usePreferredAngles: usePreferredAngles)  // UPDATED: Pass flag
            self.centeringCalculator = CenteringCalculator(simulationBounds: simulationBounds)
            self.positionUpdater = PositionUpdater(simulationBounds: simulationBounds)
        }
    
    public func temporaryDampingBoost(steps: Int = 20) {
        dampingBoostSteps = steps
    }
     
    private var simulationSteps = 0
    
    public func resetSimulation() {
        simulationSteps = 0
        stepCount = 0
        alpha = 1.0  // New: Reset alpha
    }
    
    public var isPaused: Bool = false
    
    @discardableResult
    public func simulationStep(nodes: [any NodeProtocol], edges: [GraphEdge]) -> ([any NodeProtocol], Bool) {
        if isPaused || stepCount > Constants.Physics.maxSimulationSteps { return (nodes, false) }
        stepCount += 1
        
        #if DEBUG
        let stepState = Self.signposter.beginInterval("SimulationStep", "Step \(self.stepCount), Nodes: \(nodes.count), Edges: \(edges.count)")
        #endif
        
        let (forces, quadtree) = computeRepulsions(nodes: nodes)
        var updatedForces = applyAttractions(forces: forces, edges: edges, nodes: nodes)
        updatedForces = applyCentering(forces: updatedForces, nodes: nodes)
        updatedForces = scaleForcesByAlpha(forces: updatedForces)
        
        let (tempNodes, isActive) = updatePositions(nodes: nodes, forces: updatedForces, edges: edges, quadtree: quadtree)
        let updatedNodes = postProcessNodes(tempNodes: tempNodes, isActive: isActive)
        
        logVelocityIfNeeded(nodes: updatedNodes)
        
        #if DEBUG
        Self.signposter.endInterval("SimulationStep", stepState, "Active: \(isActive)")
        #endif
        
        return (updatedNodes, isActive)
    }
    
    private func computeRepulsions(nodes: [any NodeProtocol]) -> ([NodeID: CGPoint], Quadtree?) {
        #if DEBUG
        let repulsionState = Self.signposter.beginInterval("RepulsionCalculation")
        #endif
        let result = repulsionCalculator.computeRepulsions(nodes: nodes)
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
    
    private func applyCentering(forces: [NodeID: CGPoint], nodes: [any NodeProtocol]) -> [NodeID: CGPoint] {
        #if DEBUG
        let centeringState = Self.signposter.beginInterval("CenteringCalculation")
        #endif
        let result = centeringCalculator.applyCentering(forces: forces, nodes: nodes)
        #if DEBUG
        Self.signposter.endInterval("CenteringCalculation", centeringState)
        #endif
        return result
    }
    
    private func scaleForcesByAlpha(forces: [NodeID: CGPoint]) -> [NodeID: CGPoint] {
        #if DEBUG
        let scalingState = Self.signposter.beginInterval("ForceScaling", "Alpha: \(self.alpha)")
        #endif
        var updatedForces = forces
        for id in updatedForces.keys {
            updatedForces[id]! *= alpha
        }
        #if DEBUG
        Self.signposter.endInterval("ForceScaling", scalingState)
        #endif
        return updatedForces
    }
    
    private func updatePositions(nodes: [any NodeProtocol], forces: [NodeID: CGPoint], edges: [GraphEdge], quadtree: Quadtree?) -> ([any NodeProtocol], Bool) {
        #if DEBUG
        let positionState = Self.signposter.beginInterval("PositionUpdate")
        #endif
        let result = positionUpdater.updatePositionsAndVelocities(nodes: nodes, forces: forces, edges: edges, quadtree: quadtree)
        #if DEBUG
        Self.signposter.endInterval("PositionUpdate", positionState)
        #endif
        return result
    }
    
    private func postProcessNodes(tempNodes: [any NodeProtocol], isActive: Bool) -> [any NodeProtocol] {
        let updatedNodes = tempNodes.map { node in
            var clamped = node
            if hypot(clamped.velocity.x, clamped.velocity.y) < 0.001 {
                clamped.velocity = .zero
            }
            return clamped
        }
        
        var resetNodes = isActive ? updatedNodes : updatedNodes.map { $0.with(position: $0.position, velocity: CGPoint.zero) }
        
        if dampingBoostSteps > 0 {
            #if DEBUG
            let dampingState = Self.signposter.beginInterval("DampingBoost", "Remaining steps: \(self.dampingBoostSteps)")
            #endif
            let extraDamping = Constants.Physics.damping * 1.2
            resetNodes = resetNodes.map { node in
                var boostedNode = node
                boostedNode.velocity *= extraDamping
                return boostedNode
            }
            dampingBoostSteps -= 1
            #if DEBUG
            Self.signposter.endInterval("DampingBoost", dampingState)
            #endif
        }
        
        return resetNodes
    }
    
    private func logVelocityIfNeeded(nodes: [any NodeProtocol]) {
        if stepCount % 10 == 0 {  // Reduced logging frequency
            let totalVel = nodes.reduce(0.0) { $0 + $1.velocity.magnitude }
            Self.logger.debugLog("Step \(stepCount): Total velocity = \(String(format: "%.2f", totalVel))")
            #if DEBUG
            Self.signposter.emitEvent("VelocityCheck", "Step \(self.stepCount): Total velocity = \(totalVel)")
            #endif
        }
    }
    
    // Add to PhysicsEngine class
    public func runSimulation(steps: Int, nodes: [any NodeProtocol], edges: [GraphEdge]) -> [any NodeProtocol] {
        #if DEBUG
        let runState = Self.signposter.beginInterval("RunSimulation", "Steps: \(steps), Nodes: \(nodes.count)")
        #endif
        var currentNodes = nodes
        for _ in 0..<steps {
            let (updatedNodes, isActive) = simulationStep(nodes: currentNodes, edges: edges)
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
        guard !nodes.isEmpty else { return .zero }
        var minX = nodes[0].position.x, minY = nodes[0].position.y
        var maxX = nodes[0].position.x, maxY = nodes[0].position.y
        for node in nodes {
            minX = min(minX, node.position.x - node.radius)
            minY = min(minY, node.position.y - node.radius)
            maxX = max(maxX, node.position.x + node.radius)
            maxY = max(maxY, node.position.y + node.radius)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
