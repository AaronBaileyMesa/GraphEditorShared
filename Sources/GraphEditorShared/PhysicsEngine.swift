//
//  PhysicsEngine.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//

import SwiftUI
import Foundation
import CoreGraphics

@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public class PhysicsEngine {
    let simulationBounds: CGSize
    
    private let maxNodesForQuadtree = 200
    
    public init(simulationBounds: CGSize) {
        self.simulationBounds = simulationBounds
    }
    
    private var simulationSteps = 0
    
    public func resetSimulation() {
        simulationSteps = 0
    }
    
    public var useAsymmetricAttraction: Bool = false
    
    public var isPaused: Bool = false
    
    @discardableResult
    public func simulationStep(nodes: [any NodeProtocol], edges: [GraphEdge]) -> ([any NodeProtocol], Bool) {
        // Early exit if simulation is paused
        if isPaused { return (nodes, false) }
        
        // Early exit if maximum simulation steps reached
        if simulationSteps >= Constants.Physics.maxSimulationSteps {
            return (nodes, false)
        }
        simulationSteps += 1
        
        var forces: [NodeID: CGPoint] = [:]
        let center = CGPoint(x: simulationBounds.width / 2, y: simulationBounds.height / 2)
        
        // Build Quadtree for repulsion (Barnes-Hut) only if under node cap
        let useQuadtree = nodes.count <= maxNodesForQuadtree
        let quadtree: Quadtree? = useQuadtree ? Quadtree(bounds: CGRect(origin: .zero, size: simulationBounds)) : nil
        if useQuadtree {
            for node in nodes {
                quadtree?.insert(node, depth: 0)
            }
        }
        
        // Calculate repulsion forces
        for node in nodes {
            var repulsion: CGPoint = .zero
            if useQuadtree {
                let dynamicTheta: CGFloat = nodes.count > 100 ? 1.5 : (nodes.count > 50 ? 1.2 : 0.8)
                repulsion = quadtree!.computeForce(on: node, theta: dynamicTheta)
            } else {
                for otherNode in nodes where otherNode.id != node.id {
                    repulsion += repulsionForce(from: otherNode.position, to: node.position)
                }
            }
            forces[node.id] = (forces[node.id] ?? .zero) + repulsion
        }
        
        // Calculate attraction forces on edges
        for edge in edges {
            guard let fromNode = nodes.first(where: { $0.id == edge.from }),
                  let toNode = nodes.first(where: { $0.id == edge.to }) else { continue }
            let deltaX = toNode.position.x - fromNode.position.x
            let deltaY = toNode.position.y - fromNode.position.y
            let dist = max(hypot(deltaX, deltaY), Constants.Physics.distanceEpsilon)
            let forceMagnitude = Constants.Physics.stiffness * (dist - Constants.Physics.idealLength)
            let forceDirectionX = deltaX / dist
            let forceDirectionY = deltaY / dist
            let forceX = forceDirectionX * forceMagnitude
            let forceY = forceDirectionY * forceMagnitude
            
            if useAsymmetricAttraction {
                // Asymmetric: Stronger pull on 'to' node
                let currentForceFrom = forces[fromNode.id] ?? .zero
                forces[fromNode.id] = CGPoint(x: currentForceFrom.x + forceX * 0.5, y: currentForceFrom.y + forceY * 0.5)
                let currentForceTo = forces[toNode.id] ?? .zero
                forces[toNode.id] = CGPoint(x: currentForceTo.x - forceX * 1.5, y: currentForceTo.y - forceY * 1.5)
            } else {
                let currentForceFrom = forces[fromNode.id] ?? .zero
                forces[fromNode.id] = CGPoint(x: currentForceFrom.x + forceX, y: currentForceFrom.y + forceY)
                let currentForceTo = forces[toNode.id] ?? .zero
                forces[toNode.id] = CGPoint(x: currentForceTo.x - forceX, y: currentForceTo.y - forceY)
            }
        }
        
        // Apply centering force to each node
        for node in nodes {
            let deltaX = center.x - node.position.x
            let deltaY = center.y - node.position.y
            let distToCenter = hypot(deltaX, deltaY)
            let forceX = deltaX * Constants.Physics.centeringForce * (1 + distToCenter / max(simulationBounds.width, simulationBounds.height))
            let forceY = deltaY * Constants.Physics.centeringForce * (1 + distToCenter / max(simulationBounds.width, simulationBounds.height))
            let currentForce = forces[node.id] ?? .zero
            forces[node.id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
        }
        
        // First pass: Compute tentative position and velocity for all nodes
        var tentativeUpdates: [NodeID: (position: CGPoint, velocity: CGPoint)] = [:]
        for node in nodes {
            let force = forces[node.id] ?? .zero
            var newVelocity = CGPoint(x: node.velocity.x + force.x * Constants.Physics.timeStep, y: node.velocity.y + force.y * Constants.Physics.timeStep)
            newVelocity = CGPoint(x: newVelocity.x * Constants.Physics.damping, y: newVelocity.y * Constants.Physics.damping)
            var newPosition = CGPoint(x: node.position.x + newVelocity.x * Constants.Physics.timeStep, y: node.position.y + newVelocity.y * Constants.Physics.timeStep)
            
            // Tentative bounds clamp and bounce
            let oldPosition = newPosition
            newPosition.x = max(0, min(simulationBounds.width, newPosition.x))
            newPosition.y = max(0, min(simulationBounds.height, newPosition.y))
            if newPosition.x != oldPosition.x {
                newVelocity.x = -newVelocity.x * Constants.Physics.damping
            }
            if newPosition.y != oldPosition.y {
                newVelocity.y = -newVelocity.y * Constants.Physics.damping
            }
            
            tentativeUpdates[node.id] = (newPosition, newVelocity)
        }
        
        // Second pass: Apply clamping using tentative parent updates and create final updated nodes
        var updatedNodes: [any NodeProtocol] = []
        let parentMap = edges.reduce(into: [NodeID: NodeID]()) { $0[$1.to] = $1.from }  // Child to parent (assume single parent)
        var totalVelocity: CGFloat = 0.0
        for node in nodes {
            var newPosition = tentativeUpdates[node.id]!.position
            var newVelocity = tentativeUpdates[node.id]!.velocity
            
            if let parentID = parentMap[node.id],
               let parent = nodes.first(where: { $0.id == parentID }),
               !parent.isExpanded {
                // Clamp to parent's tentative new position
                newPosition = tentativeUpdates[parentID]!.position
                newVelocity = .zero
            }
            
            let updatedNode = node.with(position: newPosition, velocity: newVelocity)
            updatedNodes.append(updatedNode)
            totalVelocity += hypot(newVelocity.x, newVelocity.y)
        }
        
        // Check if stable based on total velocity
        let isActive = totalVelocity >= Constants.Physics.velocityThreshold * CGFloat(nodes.count)
        
        return (updatedNodes, isActive)
    }
    
    public func boundingBox(nodes: [any NodeProtocol]) -> CGRect {
        if nodes.isEmpty { return .zero }
        let xs = nodes.map { $0.position.x }
        let ys = nodes.map { $0.position.y }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
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
    
    private func repulsionForce(from: CGPoint, to: CGPoint) -> CGPoint {
        let delta = to - from
        let distSquared = delta.x * delta.x + delta.y * delta.y
        if distSquared < Constants.Physics.distanceEpsilon * Constants.Physics.distanceEpsilon {
            return CGPoint(x: CGFloat.random(in: -0.01...0.01), y: CGFloat.random(in: -0.01...0.01)) * Constants.Physics.repulsion
        }
        let dist = sqrt(distSquared)
        let forceMagnitude = Constants.Physics.repulsion / distSquared
        return delta / dist * forceMagnitude
    }
}
