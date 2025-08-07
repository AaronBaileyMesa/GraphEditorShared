//
//  Constants.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Sources/GraphEditorShared/PhysicsEngine.swift

import SwiftUI
import Foundation
import CoreGraphics

@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public class PhysicsEngine {
    let simulationBounds: CGSize
    
    private let maxNodesForQuadtree = 200  // Added constant for node cap fallback
    
    public init(simulationBounds: CGSize) {
        self.simulationBounds = simulationBounds
        self.useAsymmetricAttraction = true  // Enable for directed graphs (creates hierarchy)
    }
    
    private var simulationSteps = 0
    
    public func resetSimulation() {
        simulationSteps = 0
    }
    
    public var useAsymmetricAttraction: Bool = false  // New: Toggle for directed physics (default false for stability)
    
    public var isPaused: Bool = false  // New: Flag to pause simulation steps
    
    @discardableResult
    public func simulationStep(nodes: inout [Node], edges: [GraphEdge]) -> Bool {
        if isPaused { return false }
        
        if simulationSteps >= Constants.Physics.maxSimulationSteps {
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
                let dynamicTheta: CGFloat = nodes.count > 100 ? 1.5 : (nodes.count > 50 ? 1.2 : 0.8)
                repulsion = quadtree!.computeForce(on: nodes[i], theta: dynamicTheta)
            } else {
                for j in 0..<nodes.count where i != j {
                    repulsion += repulsionForce(from: nodes[j].position, to: nodes[i].position)
                }
            }
            forces[nodes[i].id] = (forces[nodes[i].id] ?? .zero) + repulsion
        }
        
        // Attraction on edges
        for edge in edges {
            guard let fromIdx = nodes.firstIndex(where: { $0.id == edge.from }),
                  let toIdx = nodes.firstIndex(where: { $0.id == edge.to }) else { continue }
            let deltaX = nodes[toIdx].position.x - nodes[fromIdx].position.x
            let deltaY = nodes[toIdx].position.y - nodes[fromIdx].position.y
            let dist = max(hypot(deltaX, deltaY), Constants.Physics.distanceEpsilon)
            let forceMagnitude = Constants.Physics.stiffness * (dist - Constants.Physics.idealLength)
            let forceDirectionX = deltaX / dist
            let forceDirectionY = deltaY / dist
            let forceX = forceDirectionX * forceMagnitude
            let forceY = forceDirectionY * forceMagnitude
            
            if useAsymmetricAttraction {
                // Asymmetric: Stronger pull on 'to' node
                let currentForceFrom = forces[nodes[fromIdx].id] ?? .zero
                forces[nodes[fromIdx].id] = CGPoint(x: currentForceFrom.x + forceX * 0.5, y: currentForceFrom.y + forceY * 0.5)
                let currentForceTo = forces[nodes[toIdx].id] ?? .zero
                forces[nodes[toIdx].id] = CGPoint(x: currentForceTo.x - forceX * 1.5, y: currentForceTo.y - forceY * 1.5)
            } else {
                let currentForceFrom = forces[nodes[fromIdx].id] ?? .zero
                forces[nodes[fromIdx].id] = CGPoint(x: currentForceFrom.x + forceX, y: currentForceFrom.y + forceY)
                let currentForceTo = forces[nodes[toIdx].id] ?? .zero
                forces[nodes[toIdx].id] = CGPoint(x: currentForceTo.x - forceX, y: currentForceTo.y - forceY)
            }
        }
        
        // Weak centering force
        for i in 0..<nodes.count {
            let deltaX = center.x - nodes[i].position.x
            let deltaY = center.y - nodes[i].position.y
            let forceX = deltaX * Constants.Physics.centeringForce
            let forceY = deltaY * Constants.Physics.centeringForce
            let currentForce = forces[nodes[i].id] ?? .zero
            forces[nodes[i].id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
        }
        
        // Apply forces
        for i in 0..<nodes.count {
            let id = nodes[i].id
            var node = nodes[i]
            let force = forces[id] ?? .zero
            node.velocity = CGPoint(x: node.velocity.x + force.x * Constants.Physics.timeStep, y: node.velocity.y + force.y * Constants.Physics.timeStep)
            node.velocity = CGPoint(x: node.velocity.x * Constants.Physics.damping, y: node.velocity.y * Constants.Physics.damping)
            node.position = CGPoint(x: node.position.x + node.velocity.x * Constants.Physics.timeStep, y: node.position.y + node.velocity.y * Constants.Physics.timeStep)
            
            // Clamp position and bounce on bounds hit
            let oldPosition = node.position
            node.position.x = max(0, min(simulationBounds.width, node.position.x))
            node.position.y = max(0, min(simulationBounds.height, node.position.y))
            if node.position.x != oldPosition.x {
                node.velocity.x = -node.velocity.x * Constants.Physics.damping
            }
            if node.position.y != oldPosition.y {
                node.velocity.y = -node.velocity.y * Constants.Physics.damping
            }
            
            nodes[i] = node
        }
        
        // Check if stable (velocity only)
        let totalVelocity = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
        return totalVelocity >= Constants.Physics.velocityThreshold * CGFloat(nodes.count)
    }
    @available(iOS 13.0, *)
    @available(watchOS 9.0, *)
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
    
    private func repulsionForce(from: CGPoint, to: CGPoint) -> CGPoint {
        let delta = to - from
        let distSquared = delta.x * delta.x + delta.y * delta.y  // Manual calculation instead of magnitudeSquared
        if distSquared < Constants.Physics.distanceEpsilon * Constants.Physics.distanceEpsilon {
            return CGPoint(x: CGFloat.random(in: -0.01...0.01), y: CGFloat.random(in: -0.01...0.01)) * Constants.Physics.repulsion
        }
        let dist = sqrt(distSquared)
        let forceMagnitude = Constants.Physics.repulsion / distSquared
        return delta / dist * forceMagnitude
    }
}
