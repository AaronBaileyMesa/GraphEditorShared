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
    internal let attractionCalculator: AttractionCalculator
    internal let centeringCalculator: CenteringCalculator
    internal let positionUpdater: PositionUpdater
    
    public init(simulationBounds: CGSize) {
        self.simulationBounds = simulationBounds
        self.repulsionCalculator = RepulsionCalculator(maxNodesForQuadtree: 200, simulationBounds: simulationBounds)
        self.attractionCalculator = AttractionCalculator(useAsymmetricAttraction: self.useAsymmetricAttraction, symmetricFactor: self.symmetricFactor)
        self.centeringCalculator = CenteringCalculator(simulationBounds: simulationBounds)
        self.positionUpdater = PositionUpdater(simulationBounds: simulationBounds)  // Added missing arg
    }
    
    private var simulationSteps = 0
    
    public func resetSimulation() {
        simulationSteps = 0
        stepCount = 0
    }
    
    public var useAsymmetricAttraction: Bool = false  // Default to false for stability
    public var isPaused: Bool = false
    
    @discardableResult
    public func simulationStep(nodes: [any NodeProtocol], edges: [GraphEdge]) -> ([any NodeProtocol], Bool) {
        if isPaused { return (nodes, false) }
        stepCount += 1
        if stepCount > Constants.Physics.maxSimulationSteps { return (nodes, false) }
        
        let (forces, quadtree) = repulsionCalculator.computeRepulsions(nodes: nodes)  // Updated: Unpack tuple
        
        var updatedForces = forces  // Temp var to avoid mutating forces directly
        updatedForces = attractionCalculator.applyAttractions(forces: updatedForces, edges: edges, nodes: nodes)
        updatedForces = centeringCalculator.applyCentering(forces: updatedForces, nodes: nodes)
        
        // New: Log totals every 2 steps to avoid spam
        if stepCount % 2 == 0 {
            let totalForce = updatedForces.values.reduce(0.0) { $0 + hypot($1.x, $1.y) }
            let totalVel = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
            os_log("Step %{public}d: Total force magnitude = %{public}.2f, Total velocity = %{public}.2f", log: physicsLogger, type: .debug, stepCount, totalForce, totalVel)
        }

        let (updatedNodes, isActive) = positionUpdater.updatePositionsAndVelocities(nodes: nodes, forces: updatedForces, edges: edges, quadtree: quadtree)  // Updated: Pass quadtree
        return (updatedNodes, isActive)
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
        let dx = targetCenter.x - centroid.x
        let dy = targetCenter.y - centroid.y
        return nodes.map { node in
            let newPosition = CGPoint(x: node.position.x + dx, y: node.position.y + dy)
            return node.with(position: newPosition, velocity: node.velocity)
        }
    }
}
