//
//  Constants.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Models/PhysicsEngine.swift
import SwiftUI
import Foundation
import CoreGraphics

public class PhysicsEngine {
    let simulationBounds: CGSize
    
    private let maxNodesForQuadtree = 100  // Added constant for node cap fallback
    
    public init(simulationBounds: CGSize) {
        self.simulationBounds = simulationBounds
    }
    
    private var simulationSteps = 0
    
    public func resetSimulation() {
        simulationSteps = 0
    }
    
    @discardableResult
    public func simulationStep(nodes: inout [Node], edges: [GraphEdge]) -> Bool {
        if simulationSteps >= PhysicsConstants.maxSimulationSteps {
            return false
        }
        simulationSteps += 1
        
        var forces: [NodeID: CGPoint] = [:]
        let center = CGPoint(x: simulationBounds.width / 2, y: simulationBounds.height / 2)
        
        // Build Quadtree for repulsion (Barnes-Hut) only if under cap
        let useQuadtree = nodes.count <= maxNodesForQuadtree
        let quadtree: Quadtree? = useQuadtree ? Quadtree(bounds: CGRect(origin: .zero, size: simulationBounds)) : nil
        if useQuadtree {
            for node in nodes {
                quadtree?.insert(node, depth: 0)
            }
        }
        
        // Repulsion (Quadtree or naive fallback)
        for i in 0..<nodes.count {
            var repulsion: CGPoint = .zero
            if useQuadtree {
                let dynamicTheta: CGFloat = nodes.count > 50 ? 1.2 : (nodes.count > 20 ? 1.0 : 0.5)
                repulsion = quadtree!.computeForce(on: nodes[i], theta: dynamicTheta)
            } else {
                // Naive repulsion
                for j in 0..<nodes.count where i != j {
                    repulsion += repulsionForce(from: nodes[j].position, to: nodes[i].position)
                }
            }
            forces[nodes[i].id] = (forces[nodes[i].id] ?? .zero) + repulsion  // Use repulsion here
        }
        
        // Attraction on edges
        for edge in edges {
            guard let fromIdx = nodes.firstIndex(where: { $0.id == edge.from }),
                  let toIdx = nodes.firstIndex(where: { $0.id == edge.to }) else { continue }
            let deltaX = nodes[toIdx].position.x - nodes[fromIdx].position.x
            let deltaY = nodes[toIdx].position.y - nodes[fromIdx].position.y
            let dist = max(hypot(deltaX, deltaY), PhysicsConstants.distanceEpsilon)
            let forceMagnitude = PhysicsConstants.stiffness * (dist - PhysicsConstants.idealLength)
            let forceDirectionX = deltaX / dist
            let forceDirectionY = deltaY / dist
            let forceX = forceDirectionX * forceMagnitude
            let forceY = forceDirectionY * forceMagnitude
            let currentForceFrom = forces[nodes[fromIdx].id] ?? .zero
            forces[nodes[fromIdx].id] = CGPoint(x: currentForceFrom.x + forceX, y: currentForceFrom.y + forceY)
            let currentForceTo = forces[nodes[toIdx].id] ?? .zero
            forces[nodes[toIdx].id] = CGPoint(x: currentForceTo.x - forceX, y: currentForceTo.y - forceY)
        }
        
        // Weak centering force
        for i in 0..<nodes.count {
            let deltaX = center.x - nodes[i].position.x
            let deltaY = center.y - nodes[i].position.y
            let forceX = deltaX * PhysicsConstants.centeringForce
            let forceY = deltaY * PhysicsConstants.centeringForce
            let currentForce = forces[nodes[i].id] ?? .zero
            forces[nodes[i].id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
        }
        
        // Apply forces
        for i in 0..<nodes.count {
            let id = nodes[i].id
            var node = nodes[i]
            let force = forces[id] ?? .zero
            node.velocity = CGPoint(x: node.velocity.x + force.x * PhysicsConstants.timeStep, y: node.velocity.y + force.y * PhysicsConstants.timeStep)
            node.velocity = CGPoint(x: node.velocity.x * PhysicsConstants.damping, y: node.velocity.y * PhysicsConstants.damping)
            node.position = CGPoint(x: node.position.x + node.velocity.x * PhysicsConstants.timeStep, y: node.position.y + node.velocity.y * PhysicsConstants.timeStep)
            
            // Clamp position and reset velocity on bounds hit (with bounce from earlier fix)
            let oldPosition = node.position
            node.position.x = max(0, min(simulationBounds.width, node.position.x))
            node.position.y = max(0, min(simulationBounds.height, node.position.y))
            if node.position.x != oldPosition.x {
                node.velocity.x = -node.velocity.x * PhysicsConstants.damping  // Bounce
            }
            if node.position.y != oldPosition.y {
                node.velocity.y = -node.velocity.y * PhysicsConstants.damping
            }
            
            nodes[i] = node
        }
        
        // Check if stable
        let totalVelocity = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
        return totalVelocity >= PhysicsConstants.velocityThreshold * CGFloat(nodes.count)
    }
    
    public func boundingBox(nodes: [Node]) -> CGRect {
        if nodes.isEmpty { return .zero }
        let xs = nodes.map { $0.position.x }
        let ys = nodes.map { $0.position.y }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func repulsionForce(from: CGPoint, to: CGPoint) -> CGPoint {
        let delta = to - from
        let distSquared = delta.x * delta.x + delta.y * delta.y  // Manual calculation instead of magnitudeSquared
        if distSquared < PhysicsConstants.distanceEpsilon * PhysicsConstants.distanceEpsilon {
            return CGPoint(x: CGFloat.random(in: -0.01...0.01), y: CGFloat.random(in: -0.01...0.01)) * PhysicsConstants.repulsion
        }
        let dist = sqrt(distSquared)
        let forceMagnitude = PhysicsConstants.repulsion / distSquared
        return delta / dist * forceMagnitude
    }
}
