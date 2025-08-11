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
    
    public var useAsymmetricAttraction: Bool = false  // Default to false for stability
    public var isPaused: Bool = false
    
    @discardableResult
    public func simulationStep(nodes: [any NodeProtocol], edges: [GraphEdge]) -> ([any NodeProtocol], Bool) {
        if isPaused || simulationSteps >= Constants.Physics.maxSimulationSteps { return (nodes, false) }
        simulationSteps += 1
        
        var forces = computeRepulsions(nodes: nodes)
        forces = applyAttractions(forces: forces, edges: edges, nodes: nodes)
        forces = applyCentering(forces: forces, nodes: nodes)
        
        return updatePositionsAndVelocities(nodes: nodes, forces: forces, edges: edges)
    }
    
    private func computeRepulsions(nodes: [any NodeProtocol]) -> [NodeID: CGPoint] {
        var forces: [NodeID: CGPoint] = [:]
        
        let useQuadtree = nodes.count <= maxNodesForQuadtree && simulationBounds.width >= Constants.Physics.minQuadSize && simulationBounds.height >= Constants.Physics.minQuadSize
        let quadtree: Quadtree? = useQuadtree ? Quadtree(bounds: CGRect(origin: .zero, size: simulationBounds)) : nil
        if let quadtree = quadtree {
            for node in nodes {
                quadtree.insert(node, depth: 0)
            }
        }
        
        for node in nodes {
            var repulsion: CGPoint = .zero
            if let quadtree = quadtree {
                let dynamicTheta: CGFloat = nodes.count > 100 ? 1.5 : (nodes.count > 50 ? 1.2 : 0.8)
                repulsion = quadtree.computeForce(on: node, theta: dynamicTheta)
            } else {
                // Brute-force fallback
                for otherNode in nodes where otherNode.id != node.id {
                    repulsion += repulsionForce(from: otherNode.position, to: node.position, nodeCount: nodes.count)
                }
            }
            forces[node.id] = (forces[node.id] ?? .zero) + repulsion
        }
        return forces
    }
    
    private func applyAttractions(forces: [NodeID: CGPoint], edges: [GraphEdge], nodes: [any NodeProtocol]) -> [NodeID: CGPoint] {
        var updatedForces = forces
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
            
            let symmetricFactor: CGFloat = 0.2  // Small symmetric pull for damping
            let symForceX = forceX * symmetricFactor
            let symForceY = forceY * symmetricFactor
            
            let currentForceFrom = updatedForces[fromNode.id] ?? .zero
            updatedForces[fromNode.id] = CGPoint(x: currentForceFrom.x + symForceX, y: currentForceFrom.y + symForceY)
            
            let currentForceTo = updatedForces[toNode.id] ?? .zero
            if useAsymmetricAttraction {
                updatedForces[toNode.id] = CGPoint(x: currentForceTo.x - forceX * (1 + symmetricFactor), y: currentForceTo.y - forceY * (1 + symmetricFactor))
            } else {
                updatedForces[toNode.id] = CGPoint(x: currentForceTo.x - forceX + symForceX, y: currentForceTo.y - forceY + symForceY)  // Symmetric with damping
            }
        }
        return updatedForces
    }
    
    private func applyCentering(forces: [NodeID: CGPoint], nodes: [any NodeProtocol]) -> [NodeID: CGPoint] {
        var updatedForces = forces
        let center = CGPoint(x: simulationBounds.width / 2, y: simulationBounds.height / 2)
        for node in nodes {
            let deltaX = center.x - node.position.x
            let deltaY = center.y - node.position.y
            let distToCenter = hypot(deltaX, deltaY)
            let forceX = deltaX * Constants.Physics.centeringForce * (1 + distToCenter / max(simulationBounds.width, simulationBounds.height))
            let forceY = deltaY * Constants.Physics.centeringForce * (1 + distToCenter / max(simulationBounds.width, simulationBounds.height))
            let currentForce = updatedForces[node.id] ?? .zero
            updatedForces[node.id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
        }
        return updatedForces
    }
    
    private func updatePositionsAndVelocities(nodes: [any NodeProtocol], forces: [NodeID: CGPoint], edges: [GraphEdge]) -> ([any NodeProtocol], Bool) {
        // First pass: Compute tentative position and velocity for all nodes
        var tentativeUpdates: [NodeID: (position: CGPoint, velocity: CGPoint)] = [:]
        for node in nodes {
            let force = forces[node.id] ?? .zero
            var newVelocity = CGPoint(x: node.velocity.x + force.x * Constants.Physics.timeStep, y: node.velocity.y + force.y * Constants.Physics.timeStep)
            newVelocity = CGPoint(x: newVelocity.x * Constants.Physics.damping, y: newVelocity.y * Constants.Physics.damping)
            var newPosition = CGPoint(x: node.position.x + newVelocity.x * Constants.Physics.timeStep, y: node.position.y + newVelocity.y * Constants.Physics.timeStep)
            
            // Tentative bounds clamp and softer bounce
            let oldPosition = newPosition
            newPosition.x = max(0, min(simulationBounds.width, newPosition.x))
            newPosition.y = max(0, min(simulationBounds.height, newPosition.y))
            if newPosition.x != oldPosition.x {
                newVelocity.x = -newVelocity.x * 0.8
            }
            if newPosition.y != oldPosition.y {
                newVelocity.y = -newVelocity.y * 0.8
            }
            
            // Insert anti-collision separation here
            let minDist: CGFloat = 35.0
            for other in nodes where other.id != node.id {
                let delta = newPosition - other.position
                let d = hypot(delta.x, delta.y)
                if d < minDist && d > 0 {
                    newPosition += (delta / d) * (minDist - d) / 2
                }
            }
            
            tentativeUpdates[node.id] = (newPosition, newVelocity)
        }
        
        
        // Build multi-parent map: child -> [parents]
        var parentMap = [NodeID: [NodeID]]()
        for edge in edges {
            parentMap[edge.to, default: []].append(edge.from)
        }
        
        // Second pass: Apply clamping using tentative parent updates and create final updated nodes
        var updatedNodes: [any NodeProtocol] = []
        var totalVelocity: CGFloat = 0.0
        for node in nodes {
            var newPosition = tentativeUpdates[node.id]!.position
            var newVelocity = tentativeUpdates[node.id]!.velocity
            
            if let parents = parentMap[node.id], !parents.isEmpty {
                let collapsedParents = parents.filter { parentID in
                    nodes.first(where: { $0.id == parentID })?.isExpanded == false
                }
                if !collapsedParents.isEmpty {
                    // Average tentative positions of collapsed parents
                    var avgPos = CGPoint.zero
                    for parentID in collapsedParents {
                        avgPos = avgPos + tentativeUpdates[parentID]!.position
                    }
                    avgPos = avgPos / CGFloat(collapsedParents.count)
                    newPosition = avgPos
                    newVelocity = .zero
                }
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
    
    private func repulsionForce(from: CGPoint, to: CGPoint, nodeCount: Int) -> CGPoint {
        let delta = to - from
        let distSquared = max(delta.x * delta.x + delta.y * delta.y, Constants.Physics.distanceEpsilon * Constants.Physics.distanceEpsilon)
        let dist = sqrt(distSquared)
        let factor = 1 + 0.15 * CGFloat(nodeCount) / 5
        let forceMagnitude = (Constants.Physics.repulsion * factor) / distSquared
        return (delta / dist) * forceMagnitude  // Parens for clarity
    }
}
