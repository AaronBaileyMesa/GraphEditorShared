//
//  RepulsionCalculator.swift
//  GraphEditorShared
//
//  Created by handcart on 8/12/25.
//

import Foundation
import CoreGraphics

struct RepulsionCalculator {
    private let maxNodesForQuadtree: Int
    private let simulationBounds: CGSize

    init(maxNodesForQuadtree: Int, simulationBounds: CGSize) {
        self.maxNodesForQuadtree = maxNodesForQuadtree
        self.simulationBounds = simulationBounds
    }

    func computeRepulsions(nodes: [any NodeProtocol], layoutMode: LayoutMode = .network) -> ([NodeID: CGPoint], Quadtree?) {
        var forces: [NodeID: CGPoint] = [:]
        
        // Filter out ControlNodes - they should not participate in repulsion
        // This keeps segments aligned when control nodes appear around selected nodes
        let repellingNodes = nodes.filter { !($0 is ControlNode) }
        
        let useQuadtree = repellingNodes.count > maxNodesForQuadtree && simulationBounds.width >= Constants.Physics.minQuadSize && simulationBounds.height >= Constants.Physics.minQuadSize
        let quadtree: Quadtree? = useQuadtree ? buildQuadtree(nodes: repellingNodes) : nil

        for node in nodes {
            var repulsion: CGPoint = .zero
            if let quadtree = quadtree {
                let dynamicTheta: CGFloat = repellingNodes.count > 100 ? 1.5 : (repellingNodes.count > 50 ? 1.2 : 0.8)
                repulsion = quadtreeRepulsion(for: node, quadtree: quadtree, theta: dynamicTheta, layoutMode: layoutMode)
            } else {
                // Only calculate repulsion from non-control nodes
                for otherNode in repellingNodes where otherNode.id != node.id {
                    repulsion += repulsionForce(repellerPosition: otherNode.position, queryPosition: node.position, layoutMode: layoutMode)
                }
            }
            forces[node.id] = (forces[node.id] ?? .zero) + repulsion
        }
        return (forces, quadtree)  // New: Return tuple
    }

    public func buildQuadtree(nodes: [any NodeProtocol]) -> Quadtree {
        let boundingBox = boundingBox(nodes: nodes)  // Calls local func
        let quadtree = Quadtree(bounds: boundingBox)
        for node in nodes {
            quadtree.insert(node)
        }
        return quadtree
    }

    private func repulsionForce(repellerPosition: CGPoint, queryPosition: CGPoint, mass: CGFloat = 1.0, layoutMode: LayoutMode = .network) -> CGPoint {
        let deltaX = queryPosition.x - repellerPosition.x
        let deltaY = queryPosition.y - repellerPosition.y
        let distanceSquared = max(deltaX * deltaX + deltaY * deltaY, Constants.Physics.distanceEpsilon)
        let distance = sqrt(distanceSquared)
        let repulsionStrength = layoutMode == .hierarchy ? Constants.Physics.hierarchyRepulsion : Constants.Physics.repulsion
        let forceMagnitude = repulsionStrength * mass / distanceSquared
        return CGPoint(x: (deltaX / distance) * forceMagnitude, y: (deltaY / distance) * forceMagnitude)
    }
    
    private func quadtreeRepulsion(for node: any NodeProtocol, quadtree: Quadtree, theta: CGFloat, layoutMode: LayoutMode = .network) -> CGPoint {
        var force = CGPoint.zero
        func calculateRepulsion(quadTree: Quadtree) {
            if quadTree.children == nil {
                for other in quadTree.nodes where other.id != node.id {
                    force += repulsionForce(repellerPosition: other.position, queryPosition: node.position, mass: 1.0, layoutMode: layoutMode)
                }
                return
            }

            let deltaX = quadTree.centerOfMass.x - node.position.x
            let deltaY = quadTree.centerOfMass.y - node.position.y
            let distance = hypot(deltaX, deltaY)
            let width = quadTree.bounds.width

            if width / distance < theta && distance > 0 {  // Use theta
                let approxForce = repulsionForce(repellerPosition: quadTree.centerOfMass, queryPosition: node.position, mass: quadTree.totalMass, layoutMode: layoutMode)
                force += approxForce
            } else {
                if let children = quadTree.children {
                    calculateRepulsion(quadTree: children[0])
                    calculateRepulsion(quadTree: children[1])
                    calculateRepulsion(quadTree: children[2])
                    calculateRepulsion(quadTree: children[3])
                }
            }
        }

        calculateRepulsion(quadTree: quadtree)
        return force
    }

    // Added missing boundingBox func
    private func boundingBox(nodes: [any NodeProtocol]) -> CGRect {
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
}
