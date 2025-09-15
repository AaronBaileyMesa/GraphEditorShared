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

    private func clampedPositionAndBouncedVelocity(for tentativePosition: CGPoint, with tentativeVelocity: CGPoint) -> (CGPoint, CGPoint) {
        let oldPosition = tentativePosition
        var newPosition = tentativePosition
        newPosition.x = max(0, min(simulationBounds.width, newPosition.x))
        newPosition.y = max(0, min(simulationBounds.height, newPosition.y))
        var newVelocity = tentativeVelocity
        if newPosition.x != oldPosition.x {
            newVelocity.x = -newVelocity.x * 0.8
        }
        if newPosition.y != oldPosition.y {
            newVelocity.y = -newVelocity.y * 0.8
        }
        return (newPosition, newVelocity)
    }

    private func adjustPositionForCollisions(_ position: CGPoint, excluding nodeID: NodeID, using quadtree: Quadtree?, allNodes nodes: [any NodeProtocol]) -> CGPoint {
        let minDist: CGFloat = 35.0
        var newPosition = position
        if let quadTree = quadtree {
            let nearby = quadTree.queryNearby(position: newPosition, radius: minDist)
            for other in nearby where other.id != nodeID {
                let delta = newPosition - other.position
                let distance = hypot(delta.x, delta.y)
                if distance < minDist && distance > 0 {
                    newPosition += (delta / distance) * (minDist - distance) / 2
                }
            }
        } else {
            for other in nodes where other.id != nodeID {
                let delta = newPosition - other.position
                let distance = hypot(delta.x, delta.y)
                if distance < minDist && distance > 0 {
                    newPosition += (delta / distance) * (minDist - distance) / 2
                }
            }
        }
        return newPosition
    }

    private func buildParentMap(from edges: [GraphEdge]) -> [NodeID: [NodeID]] {
        var parentMap = [NodeID: [NodeID]]()
        for edge in edges {
            parentMap[edge.to, default: []].append(edge.from)
        }
        return parentMap
    }

    private func finalPositionAndVelocity(for nodeID: NodeID, tentative: (position: CGPoint, velocity: CGPoint), parentMap: [NodeID: [NodeID]], isExpandedMap: [NodeID: Bool], tentativeUpdates: [NodeID: (position: CGPoint, velocity: CGPoint)]) -> (CGPoint, CGPoint) {
        var newPosition = tentative.position
        var newVelocity = tentative.velocity
        if let parents = parentMap[nodeID], !parents.isEmpty {
            let collapsedParents = parents.filter { parentID in
                isExpandedMap[parentID] == false
            }
            if !collapsedParents.isEmpty {
                var avgPos = CGPoint.zero
                for parentID in collapsedParents {
                    avgPos += tentativeUpdates[parentID]!.position
                }
                avgPos /= CGFloat(collapsedParents.count)
                newPosition = avgPos
                newVelocity = .zero
            }
        }
        return (newPosition, newVelocity)
    }

    func updatePositionsAndVelocities(nodes: [any NodeProtocol], forces: [NodeID: CGPoint], edges: [GraphEdge], quadtree: Quadtree?) -> ([any NodeProtocol], Bool) {
        var tentativeUpdates: [NodeID: (position: CGPoint, velocity: CGPoint)] = [:]
        for node in nodes {
            let force = forces[node.id] ?? .zero
            var newVelocity = CGPoint(x: node.velocity.x + force.x * Constants.Physics.timeStep, y: node.velocity.y + force.y * Constants.Physics.timeStep)
            newVelocity = CGPoint(x: newVelocity.x * Constants.Physics.damping, y: newVelocity.y * Constants.Physics.damping)
            var newPosition = CGPoint(x: node.position.x + newVelocity.x * Constants.Physics.timeStep, y: node.position.y + newVelocity.y * Constants.Physics.timeStep)
            (newPosition, newVelocity) = clampedPositionAndBouncedVelocity(for: newPosition, with: newVelocity)
            newPosition = adjustPositionForCollisions(newPosition, excluding: node.id, using: quadtree, allNodes: nodes)
            tentativeUpdates[node.id] = (newPosition, newVelocity)
        }

        let parentMap = buildParentMap(from: edges)
        let isExpandedMap: [NodeID: Bool] = nodes.reduce(into: [:]) { $0[$1.id] = $1.isExpanded }

        var updatedNodes: [any NodeProtocol] = []
        var totalVelocity: CGFloat = 0.0
        for node in nodes {
            let tentative = tentativeUpdates[node.id]!
            let (newPosition, newVelocity) = finalPositionAndVelocity(for: node.id, tentative: tentative, parentMap: parentMap, isExpandedMap: isExpandedMap, tentativeUpdates: tentativeUpdates)
            let updatedNode = node.with(position: newPosition, velocity: newVelocity)
            updatedNodes.append(updatedNode)
            totalVelocity += hypot(newVelocity.x, newVelocity.y)
        }

        let isActive = totalVelocity >= Constants.Physics.velocityThreshold * CGFloat(nodes.count)

        return (updatedNodes, isActive)
    }
}
