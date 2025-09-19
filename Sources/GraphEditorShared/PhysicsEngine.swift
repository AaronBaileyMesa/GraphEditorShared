//
//  PhysicsEngine.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//

import os.log
import SwiftUI
import Foundation
import CoreGraphics

@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public class PhysicsEngine {
    private let physicsLogger = OSLog(subsystem: "io.handcart.GraphEditor", category: "physics")
    let simulationBounds: CGSize
    private var stepCount: Int = 0
    private let maxNodesForQuadtree = 200
    private let symmetricFactor: CGFloat = 0.5
    internal let repulsionCalculator: RepulsionCalculator
    private var dampingBoostSteps: Int = 0
    internal let attractionCalculator: AttractionCalculator
    internal let centeringCalculator: CenteringCalculator
    internal let positionUpdater: PositionUpdater
    public var useAsymmetricAttraction: Bool = false
    
    public init(simulationBounds: CGSize) {
        self.simulationBounds = simulationBounds
        self.repulsionCalculator = RepulsionCalculator(maxNodesForQuadtree: 200, simulationBounds: simulationBounds)
        self.attractionCalculator = AttractionCalculator(symmetricFactor: self.symmetricFactor, useAsymmetric: useAsymmetricAttraction)
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
    }
    
    public var isPaused: Bool = false
    
    @discardableResult
    public func simulationStep(nodes: [any NodeProtocol], edges: [GraphEdge]) -> ([any NodeProtocol], Bool) {
        if isPaused || stepCount > Constants.Physics.maxSimulationSteps { return (nodes, false) }
        stepCount += 1
        
        let (forces, quadtree) = repulsionCalculator.computeRepulsions(nodes: nodes)
        var updatedForces = attractionCalculator.applyAttractions(forces: forces, edges: edges, nodes: nodes)
        updatedForces = centeringCalculator.applyCentering(forces: updatedForces, nodes: nodes)
        
        let (tempNodes, isActive) = positionUpdater.updatePositionsAndVelocities(nodes: nodes, forces: updatedForces, edges: edges, quadtree: quadtree)
        var updatedNodes = tempNodes.map { node in
            var clamped = node
            if hypot(clamped.velocity.x, clamped.velocity.y) < 0.001 {
                clamped.velocity = .zero
            }
            return clamped
        }

        // New: Reset velocities if stable
        let resetNodes = isActive ? tempNodes : tempNodes.map { $0.with(position: $0.position, velocity: CGPoint.zero) }         // NEW: Apply boosted damping if active
//        var updatedNodes = resetNodes
        if dampingBoostSteps > 0 {
            let extraDamping = Constants.Physics.damping * 1.2  // 20% boost; adjust as needed
            updatedNodes = updatedNodes.map { node in
                var boostedNode = node
                boostedNode.velocity *= extraDamping
                return boostedNode
            }
            dampingBoostSteps -= 1
        }
        if stepCount % 10 == 0 {  // Reduced logging frequency
            let totalVel = resetNodes.reduce(0.0) { $0 + $1.velocity.magnitude }
            os_log("Step %d: Total velocity = %.2f", log: physicsLogger, type: .debug, stepCount, totalVel)
        }
        
        return (resetNodes, isActive)
    }
    
    // Add to PhysicsEngine class
    public func runSimulation(steps: Int, nodes: [any NodeProtocol], edges: [GraphEdge]) -> [any NodeProtocol] {
        var currentNodes = nodes
        for _ in 0..<steps {
            let (updatedNodes, isActive) = simulationStep(nodes: currentNodes, edges: edges)
            currentNodes = updatedNodes
            if !isActive { break }  // Early exit if stable
        }
        return currentNodes
    }
    
    public func boundingBox(nodes: [any NodeProtocol]) -> CGRect {
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
        guard !nodes.isEmpty else { return [] }
        let quadtree = repulsionCalculator.buildQuadtree(nodes: nodes)
        return quadtree.queryNearby(position: position, radius: radius)
    }
}
