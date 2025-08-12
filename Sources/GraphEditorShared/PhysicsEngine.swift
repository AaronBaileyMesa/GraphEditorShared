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
    private var stepCount: Int = 0
    private let maxNodesForQuadtree = 200
    
    public init(simulationBounds: CGSize) {
        self.simulationBounds = simulationBounds
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
        
        var forces: [CGPoint] = .init(repeating: .zero, count: nodes.count)
        var isActive = false
        
        let nodeCount = nodes.count
        let quadtree: Quadtree? = nodeCount > Constants.Physics.maxNodesForQuadtree ? buildQuadtree(nodes: nodes) : nil
        
        for i in 0..<nodes.count {
            // Repulsion
            if let quadtree = quadtree {
                forces[i] += quadtreeRepulsion(for: nodes[i], quadtree: quadtree)
            } else {
                for j in 0..<nodes.count where i != j {
                    forces[i] += repulsionForce(repellerPosition: nodes[j].position, queryPosition: nodes[i].position)
                }
            }
            
            // Springs
            for edge in edges {
                if edge.from == nodes[i].id, let toNode = nodes.first(where: { $0.id == edge.to }) {
                    forces[i] += springForce(from: nodes[i].position, to: toNode.position, idealLength: Constants.Physics.idealLength)
                }
                if edge.to == nodes[i].id, let fromNode = nodes.first(where: { $0.id == edge.from }) {
                    forces[i] += springForce(from: nodes[i].position, to: fromNode.position, idealLength: Constants.Physics.idealLength)
                }
            }
            
            // Centering
            forces[i] += CGPoint(x: -nodes[i].position.x * Constants.Physics.centeringForce, y: -nodes[i].position.y * Constants.Physics.centeringForce)
        }
        
        var updatedNodes = nodes
        for i in 0..<updatedNodes.count {
            let newVelocity = (updatedNodes[i].velocity + forces[i]) * Constants.Physics.damping
            let newPosition = updatedNodes[i].position + newVelocity * Constants.Physics.timeStep
            isActive = isActive || hypot(newVelocity.x, newVelocity.y) > Constants.Physics.velocityThreshold
            updatedNodes[i] = updatedNodes[i].with(position: newPosition, velocity: newVelocity)
        }
        
        return (updatedNodes, isActive)
    }
    
    private func quadtreeRepulsion(for node: any NodeProtocol, quadtree: Quadtree) -> CGPoint {
        var force = CGPoint.zero
        func calculateRepulsion(qt: Quadtree) {
            if qt.children == nil {
                for other in qt.nodes where other.id != node.id {
                    force += repulsionForce(repellerPosition: other.position, queryPosition: node.position)
                }
                return
            }
            
            let dx = qt.centerOfMass.x - node.position.x
            let dy = qt.centerOfMass.y - node.position.y
            let distance = hypot(dx, dy)
            let width = qt.bounds.width
            
            if width / distance < 0.5 && distance > 0 {
                let approxForce = repulsionForce(repellerPosition: qt.centerOfMass, queryPosition: node.position, mass: qt.totalMass)
                force += approxForce
            } else {
                if let children = qt.children {
                    calculateRepulsion(qt: children[0])
                    calculateRepulsion(qt: children[1])
                    calculateRepulsion(qt: children[2])
                    calculateRepulsion(qt: children[3])
                }
            }
        }
        
        calculateRepulsion(qt: quadtree)
        return force
    }
    
    private func buildQuadtree(nodes: [any NodeProtocol]) -> Quadtree {
        let boundingBox = self.boundingBox(nodes: nodes)
        let quadtree = Quadtree(bounds: boundingBox)
        for node in nodes {
            quadtree.insert(node)
        }
        return quadtree
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
                    repulsion += repulsionForce(repellerPosition: otherNode.position, queryPosition: node.position)
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
    
    private func repulsionForce(repellerPosition: CGPoint, queryPosition: CGPoint, mass: CGFloat = 1.0) -> CGPoint {
        let dx = queryPosition.x - repellerPosition.x
        let dy = queryPosition.y - repellerPosition.y
        let distanceSquared = max(dx * dx + dy * dy, Constants.Physics.distanceEpsilon)
        let distance = sqrt(distanceSquared)
        let forceMagnitude = Constants.Physics.repulsion * mass / distanceSquared
        return CGPoint(x: dx / distance * forceMagnitude, y: dy / distance * forceMagnitude)
    }
    
    private func springForce(from: CGPoint, to: CGPoint, idealLength: CGFloat) -> CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = max(hypot(dx, dy), Constants.Physics.distanceEpsilon)
        let forceMagnitude = Constants.Physics.stiffness * (distance - idealLength)
        return CGPoint(x: (dx / distance) * forceMagnitude, y: (dy / distance) * forceMagnitude)
    }
}
