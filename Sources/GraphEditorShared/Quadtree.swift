// Sources/GraphEditorShared/Quadtree.swift

import Foundation
import CoreGraphics

@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public class Quadtree {  // Made public for consistency/test access
    let bounds: CGRect
    public var centerOfMass: CGPoint = .zero
    public var totalMass: CGFloat = 0
    public var children: [Quadtree]? = nil
    var nodes: [any NodeProtocol] = []  // Updated: Existential array
    
    public init(bounds: CGRect) {
        self.bounds = bounds
    }
    
    public func insert(_ node: any NodeProtocol, depth: Int = 0) {
        guard bounds.width >= Constants.Physics.minQuadSize && bounds.height >= Constants.Physics.minQuadSize else {
            nodes.append(node)
            updateCenterOfMass(with: node)
            return
        }
        guard depth <= Constants.Physics.maxQuadtreeDepth else {
            nodes.append(node)
            updateCenterOfMass(with: node)
            return
        }
        
        if let children = children {
            // Existing subdivided quad: Insert into child
            let quadrant = getQuadrant(for: node.position)
            children[quadrant].insert(node, depth: depth + 1)
            aggregateFromChildren()  // Update aggregates post-insert
        } else if !nodes.isEmpty {
            // Leaf with nodes: Subdivide and redistribute
            subdivide()
            guard let children = children else {
                // Failed to subdivide (too small); append to leaf
                nodes.append(node)
                updateCenterOfMass(with: node)
                return
            }
            for existing in nodes {
                let quadrant = getQuadrant(for: existing.position)
                children[quadrant].insert(existing, depth: depth + 1)
            }
            nodes = []
            let quadrant = getQuadrant(for: node.position)
            children[quadrant].insert(node, depth: depth + 1)
            aggregateFromChildren()
        } else {
            // Empty leaf: Append
            nodes.append(node)
            updateCenterOfMass(with: node)
        }
    }
    
    public func batchInsert(_ batchNodes: [any NodeProtocol], depth: Int = 0) {
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
            // Existing subdivided quad: Distribute to children, defer aggregation
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
            // Leaf: If needs subdivide, do so and redistribute all
            let allNodes = nodes + batchNodes
            if allNodes.count > 1 {  // Subdivide threshold (e.g., >1 for batch)
                subdivide()
                guard let children = children else {
                    // Failed: Append to leaf
                    nodes.append(contentsOf: batchNodes)
                    for node in batchNodes {
                        updateCenterOfMass(with: node)
                    }
                    return
                }
                var childBatches: [[any NodeProtocol]] = Array(repeating: [], count: 4)
                for node in allNodes {
                    let quadrant = getQuadrant(for: node.position)
                    childBatches[quadrant].append(node)
                }
                nodes = []
                for i in 0..<4 {
                    if !childBatches[i].isEmpty {
                        children[i].batchInsert(childBatches[i], depth: depth + 1)
                    }
                }
                aggregateFromChildren()  // Aggregate once
            } else {
                // No subdivide needed: Append and update
                nodes.append(contentsOf: batchNodes)
                for node in batchNodes {
                    updateCenterOfMass(with: node)
                }
            }
        }
    }

    private func aggregateFromChildren() {
        // Recompute totalMass and centerOfMass from children (bottom-up)
        centerOfMass = .zero
        totalMass = 0
        guard let children = children else { return }
        for child in children {
            if child.totalMass > 0 {
                centerOfMass = (centerOfMass * totalMass + child.centerOfMass * child.totalMass) / (totalMass + child.totalMass)
                totalMass += child.totalMass
            }
        }
    }
    
    private func subdivide() {
        let halfWidth = bounds.width / 2
        let halfHeight = bounds.height / 2
        if halfWidth < Constants.Physics.minQuadSize || halfHeight < Constants.Physics.minQuadSize {  // Use constant
            return  // Too small
        }
        children = [
            Quadtree(bounds: CGRect(x: bounds.minX, y: bounds.minY, width: halfWidth, height: halfHeight)),
            Quadtree(bounds: CGRect(x: bounds.minX + halfWidth, y: bounds.minY, width: halfWidth, height: halfHeight)),
            Quadtree(bounds: CGRect(x: bounds.minX, y: bounds.minY + halfHeight, width: halfWidth, height: halfHeight)),
            Quadtree(bounds: CGRect(x: bounds.minX + halfWidth, y: bounds.minY + halfHeight, width: halfWidth, height: halfHeight))
        ]
    }
    
    private func getQuadrant(for point: CGPoint) -> Int {
        let midX = bounds.midX
        let midY = bounds.midY
        if point.x < midX {
            if point.y < midY { return 0 }
            else { return 2 }
        } else {
            if point.y < midY { return 1 }
            else { return 3 }
        }
    }
    
    private func updateCenterOfMass(with node: any NodeProtocol) {
        // Incremental update (works for both leaves and internals); assume mass=1 per node
        centerOfMass = (centerOfMass * totalMass + node.position) / (totalMass + 1)
        totalMass += 1
    }
    
    public func computeForce(on queryNode: any NodeProtocol, theta: CGFloat = 0.5) -> CGPoint {
        guard totalMass > 0 else { return .zero }
        if !nodes.isEmpty {
            // Leaf: Exact repulsion for each node in array
            var force: CGPoint = .zero
            for leafNode in nodes where leafNode.id != queryNode.id {
                force += repulsionForce(from: leafNode.position, to: queryNode.position)
            }
            return force
        }
        // Internal: Approximation
        let delta = centerOfMass - queryNode.position
        let dist = max(delta.magnitude, Constants.Physics.distanceEpsilon)  // Updated
        if bounds.width / dist < theta || children == nil {
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
    
    private func repulsionForce(from: CGPoint, to: CGPoint, mass: CGFloat = 1) -> CGPoint {
        let deltaX = to.x - from.x
        let deltaY = to.y - from.y
        let distSquared = deltaX * deltaX + deltaY * deltaY
        if distSquared < Constants.Physics.distanceEpsilon * Constants.Physics.distanceEpsilon {  // Updated
            // Jitter slightly to avoid zero
            return CGPoint(x: CGFloat.random(in: -0.01...0.01), y: CGFloat.random(in: -0.01...0.01)) * Constants.Physics.repulsion * mass
        }
        let dist = sqrt(distSquared)
        let forceMagnitude = Constants.Physics.repulsion * mass / distSquared
        return CGPoint(x: deltaX / dist * forceMagnitude, y: deltaY / dist * forceMagnitude)
    }
}
