//
//  PositionUpdater.swift
//  GraphEditorShared
//
//  Created by handcart on 8/12/25.
//

import Foundation
import CoreGraphics

struct PositionUpdater {
    let simulationBounds: CGSize
    
    init(simulationBounds: CGSize) {
        self.simulationBounds = simulationBounds
    }
    
    func updatePositionsAndVelocities(nodes: [any NodeProtocol], forces: [NodeID: CGPoint], edges: [GraphEdge]) -> ([any NodeProtocol], Bool) {
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
}
