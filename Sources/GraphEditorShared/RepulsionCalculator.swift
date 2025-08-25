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

    func computeRepulsions(nodes: [any NodeProtocol]) -> ([NodeID: CGPoint], Quadtree?) {
        var forces: [NodeID: CGPoint] = [:]
        let useQuadtree = nodes.count > maxNodesForQuadtree && simulationBounds.width >= Constants.Physics.minQuadSize && simulationBounds.height >= Constants.Physics.minQuadSize
        let quadtree: Quadtree? = useQuadtree ? buildQuadtree(nodes: nodes) : nil

        for node in nodes {
            var repulsion: CGPoint = .zero
            if let quadtree = quadtree {
                let dynamicTheta: CGFloat = nodes.count > 100 ? 1.5 : (nodes.count > 50 ? 1.2 : 0.8)
                repulsion = quadtreeRepulsion(for: node, quadtree: quadtree, theta: dynamicTheta)  // Updated call
            } else {
                for otherNode in nodes where otherNode.id != node.id {
                    repulsion += repulsionForce(repellerPosition: otherNode.position, queryPosition: node.position)
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

    private func repulsionForce(repellerPosition: CGPoint, queryPosition: CGPoint, mass: CGFloat = 1.0) -> CGPoint {
        let dx = queryPosition.x - repellerPosition.x
        let dy = queryPosition.y - repellerPosition.y
        let distanceSquared = max(dx * dx + dy * dy, Constants.Physics.distanceEpsilon)
        let distance = sqrt(distanceSquared)
        let forceMagnitude = Constants.Physics.repulsion * mass / distanceSquared
        return CGPoint(x: (dx / distance) * forceMagnitude, y: (dy / distance) * forceMagnitude)
    }
    
    private func quadtreeRepulsion(for node: any NodeProtocol, quadtree: Quadtree, theta: CGFloat) -> CGPoint {  // Added theta
        var force = CGPoint.zero
        func calculateRepulsion(qt: Quadtree) {
            if qt.children == nil {
                for other in qt.nodes where other.id != node.id {
                    force += repulsionForce(repellerPosition: other.position, queryPosition: node.position, mass: 1.0)
                }
                return
            }

            let dx = qt.centerOfMass.x - node.position.x
            let dy = qt.centerOfMass.y - node.position.y
            let distance = hypot(dx, dy)
            let width = qt.bounds.width

            if width / distance < theta && distance > 0 {  // Use theta
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
