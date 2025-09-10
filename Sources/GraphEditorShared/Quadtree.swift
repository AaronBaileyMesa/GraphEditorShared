//
//  Quadtree.swift
//  GraphEditorShared
//
//  Created by [original author]; updated for completeness and consistency.
//

import Foundation
import CoreGraphics

@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public class Quadtree {  // Public for consistency and test access
    let bounds: CGRect
    public var centerOfMass: CGPoint = .zero
    public var totalMass: CGFloat = 0
    public var children: [Quadtree]? = nil
    var nodes: [any NodeProtocol] = []  // Existential array for protocol conformance
    
    public init(bounds: CGRect) {
        self.bounds = bounds
    }
    
    public func insert(_ node: any NodeProtocol, depth: Int = 0) {
        // Guard against invalid bounds or excessive depth
        guard bounds.width >= Constants.Physics.minQuadSize,
              bounds.height >= Constants.Physics.minQuadSize,
              depth <= Constants.Physics.maxQuadtreeDepth else {
            nodes.append(node)
            updateCenterOfMass(with: node)
            return
        }
        
        if let children = children {
            // Existing subdivided quad: Insert into appropriate child
            let quadrant = getQuadrant(for: node.position)
            children[quadrant].insert(node, depth: depth + 1)
            aggregateFromChildren()  // Update aggregates post-insert
        } else if !nodes.isEmpty {
            // Leaf with nodes: Subdivide and redistribute all (including new node)
            subdivide()
            guard let children = children else {
                // Failed to subdivide (too small); append to leaf
                nodes.append(node)
                updateCenterOfMass(with: node)
                return
            }
            // Redistribute existing nodes
            for existing in nodes {
                let quadrant = getQuadrant(for: existing.position)
                children[quadrant].insert(existing, depth: depth + 1)
            }
            nodes = []  // Clear leaf nodes after redistribution
            // Insert the new node
            let quadrant = getQuadrant(for: node.position)
            children[quadrant].insert(node, depth: depth + 1)
            aggregateFromChildren()
        } else {
            // Empty leaf: Simply append
            nodes.append(node)
            updateCenterOfMass(with: node)
        }
    }
    
    public func batchInsert(_ batchNodes: [any NodeProtocol], depth: Int = 0) {
        // Guard against invalid bounds or excessive depth
        guard depth <= Constants.Physics.maxQuadtreeDepth,
              bounds.width >= Constants.Physics.minQuadSize,
              bounds.height >= Constants.Physics.minQuadSize else {
            nodes.append(contentsOf: batchNodes)
            for node in batchNodes {
                updateCenterOfMass(with: node)  // Incremental updates
            }
            return
        }
        
        if let children = children {
            // Existing subdivided quad: Distribute batch to children, defer aggregation
            var childBatches: [[any NodeProtocol]] = Array(repeating: [], count: 4)
            for node in batchNodes {
                let quadrant = getQuadrant(for: node.position)
                childBatches[quadrant].append(node)
            }
            for i in 0..<4 {
                if !childBatches[i].isEmpty {
                    children[i].batchInsert(childBatches[i], depth: depth + 1)
                }
            }
            aggregateFromChildren()  // Aggregate once after all inserts
        } else if !nodes.isEmpty || !batchNodes.isEmpty {
            // Leaf: Check if subdivision is needed
            let allNodes = nodes + batchNodes
            if allNodes.count > 1 {  // Subdivide threshold (tunable)
                subdivide()
                guard let children = children else {
                    // Failed to subdivide: Append batch to leaf
                    nodes.append(contentsOf: batchNodes)
                    for node in batchNodes {
                        updateCenterOfMass(with: node)
                    }
                    return
                }
                // Redistribute all nodes (existing + batch)
                var childBatches: [[any NodeProtocol]] = Array(repeating: [], count: 4)
                for node in allNodes {
                    let quadrant = getQuadrant(for: node.position)
                    childBatches[quadrant].append(node)
                }
                nodes = []  // Clear leaf
                for i in 0..<4 {
                    if !childBatches[i].isEmpty {
                        children[i].batchInsert(childBatches[i], depth: depth + 1)
                    }
                }
                aggregateFromChildren()  // Aggregate once
            } else {
                // No subdivision needed: Append batch
                nodes.append(contentsOf: batchNodes)
                for node in batchNodes {
                    updateCenterOfMass(with: node)
                }
            }
        }
    }

    private func aggregateFromChildren() {
        // Recompute totalMass and centerOfMass from children (bottom-up weighted average)
        centerOfMass = .zero
        totalMass = 0
        guard let children = children else { return }
        for child in children {
            if child.totalMass > 0 {
                let newTotalMass = totalMass + child.totalMass
                if newTotalMass > 0 {  // Avoid division by zero
                    centerOfMass = (centerOfMass * totalMass + child.centerOfMass * child.totalMass) / newTotalMass
                }
                totalMass = newTotalMass
            }
        }
    }
    
    private func subdivide() {
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        guard halfWidth >= Constants.Physics.minQuadSize && halfHeight >= Constants.Physics.minQuadSize else {
            return  // Too small to subdivide
        }
        children = [
            Quadtree(bounds: CGRect(x: bounds.minX, y: bounds.minY, width: halfWidth, height: halfHeight)),      // SW
            Quadtree(bounds: CGRect(x: bounds.minX + halfWidth, y: bounds.minY, width: halfWidth, height: halfHeight)), // SE
            Quadtree(bounds: CGRect(x: bounds.minX, y: bounds.minY + halfHeight, width: halfWidth, height: halfHeight)), // NW
            Quadtree(bounds: CGRect(x: bounds.minX + halfWidth, y: bounds.minY + halfHeight, width: halfWidth, height: halfHeight)) // NE
        ]
    }
    
    private func getQuadrant(for point: CGPoint) -> Int {
        let midX = bounds.midX
        let midY = bounds.midY
        if point.x < midX {
            return point.y < midY ? 0 : 2  // 0: SW, 2: NW
        } else {
            return point.y < midY ? 1 : 3  // 1: SE, 3: NE
        }
    }
    
    private func updateCenterOfMass(with node: any NodeProtocol) {
        // Incremental update assuming unit mass per node (extend protocol if variable mass needed)
        let newTotalMass = totalMass + 1
        if newTotalMass > 0 {
            centerOfMass = (centerOfMass * totalMass + node.position) / newTotalMass
        }
        totalMass = newTotalMass
    }
    
    public func computeForce(on queryNode: any NodeProtocol, theta: CGFloat = 0.5) -> CGPoint {
        guard totalMass > 0 else { return .zero }
        
        if !nodes.isEmpty {
            // Leaf: Compute exact repulsion from each node
            var force: CGPoint = .zero
            for leafNode in nodes where leafNode.id != queryNode.id {
                force += repulsionForce(from: leafNode.position, to: queryNode.position)
            }
            return force
        }
        
        // Internal node: Use Barnes-Hut approximation
        let delta = centerOfMass - queryNode.position
        let dist = max(hypot(delta.x, delta.y), Constants.Physics.distanceEpsilon)  // Fixed: Use hypot instead of .magnitude
        if (bounds.width / dist) < theta || children == nil {
            return repulsionForce(from: centerOfMass, to: queryNode.position, mass: totalMass)
        } else {
            var force: CGPoint = .zero
            if let children = children {
                for child in children {
                    force += child.computeForce(on: queryNode, theta: theta)
                }
            }
            return force
        }
    }
    
    public func queryNearby(position: CGPoint, radius: CGFloat) -> [any NodeProtocol] {
        var results: [any NodeProtocol] = []
        func traverse(qt: Quadtree) {
            // Quick reject: Check if quad intersects query circle
            let closestX = max(qt.bounds.minX, min(position.x, qt.bounds.maxX))
            let closestY = max(qt.bounds.minY, min(position.y, qt.bounds.maxY))
            let distToQuad = hypot(closestX - position.x, closestY - position.y)
            let quadDiagonalHalf = hypot(qt.bounds.width / 2, qt.bounds.height / 2)
            if distToQuad > radius + quadDiagonalHalf { return }  // No intersection
            
            if let children = qt.children {
                // Traverse children
                for child in children {
                    traverse(qt: child)
                }
            } else {
                // Leaf: Check individual nodes
                for node in qt.nodes {
                    let delta = node.position - position
                    if hypot(delta.x, delta.y) < radius {
                        results.append(node)
                    }
                }
            }
        }
        traverse(qt: self)
        return results
    }
    
    private func repulsionForce(from: CGPoint, to: CGPoint, mass: CGFloat = 1) -> CGPoint {
        let deltaX = to.x - from.x
        let deltaY = to.y - from.y
        let distSquared = deltaX * deltaX + deltaY * deltaY
        let epsilonSquared = Constants.Physics.distanceEpsilon * Constants.Physics.distanceEpsilon
        if distSquared < epsilonSquared {
            // Jitter to avoid singularity
            return CGPoint(
                x: CGFloat.random(in: -0.01...0.01),
                y: CGFloat.random(in: -0.01...0.01)
            ) * Constants.Physics.repulsion * mass
        }
        let dist = sqrt(distSquared)
        let forceMagnitude = Constants.Physics.repulsion * mass / distSquared
        return CGPoint(x: (deltaX / dist) * forceMagnitude, y: (deltaY / dist) * forceMagnitude)
    }
}
