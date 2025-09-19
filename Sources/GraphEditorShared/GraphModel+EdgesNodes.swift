//
//  GraphModel+EdgesNodes.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    public func wouldCreateCycle(withNewEdgeFrom from: NodeID, target: NodeID, type: EdgeType) -> Bool {
        guard type == EdgeType.hierarchy else { return false } // Changed to EdgeType.hierarchy
        var tempEdges = edges.filter { $0.type == EdgeType.hierarchy } // Changed to EdgeType.hierarchy
        tempEdges.append(GraphEdge(from: from, target: target, type: type))
        return !isAcyclic(edges: tempEdges)
    }

    private func isAcyclic(edges: [GraphEdge]) -> Bool {
        var adj: [NodeID: [NodeID]] = [:]
        var inDegree: [NodeID: Int] = [:]
        nodes.forEach { inDegree[$0.id] = 0 }
        for edge in edges {
            adj[edge.from, default: []].append(edge.target)
            inDegree[edge.target, default: 0] += 1
        }
        var queue = nodes.filter { inDegree[$0.id] == 0 }.map { $0.id }
        var count = 0
        while !queue.isEmpty {
            let node = queue.removeFirst()
            count += 1
            for neighbor in adj[node] ?? [] {
                inDegree[neighbor]! -= 1
                if inDegree[neighbor]! == 0 { queue.append(neighbor) }
            }
        }
        return count == nodes.count
    }

    public func addEdge(from: NodeID, target: NodeID, type: EdgeType) async {
            if wouldCreateCycle(withNewEdgeFrom: from, target: target, type: type) {
                print("Cannot add edge: Would create cycle in hierarchy")
                return
            }
            edges.append(GraphEdge(from: from, target: target, type: type))
            objectWillChange.send()
            await startSimulation()
        }

    public func deleteEdge(withID id: UUID) async {
        edges.removeAll { $0.id == id }
        objectWillChange.send()
        await startSimulation()
    }

    public func addNode(at position: CGPoint) async {
        let newLabel = nextNodeLabel
        nextNodeLabel += 1
        let newNode = AnyNode(Node(label: newLabel, position: position))
        nodes.append(newNode)
        objectWillChange.send()
        await startSimulation()
    }

    public func addToggleNode(at position: CGPoint) async {
        let newLabel = nextNodeLabel
        nextNodeLabel += 1
        let newNode = AnyNode(ToggleNode(label: newLabel, position: position))
        nodes.append(newNode)
        objectWillChange.send()
        await startSimulation()
    }

    public func addChild(to parentID: NodeID) async {
            let newLabel = nextNodeLabel
            nextNodeLabel += 1
            guard let parentIndex = nodes.firstIndex(where: { $0.id == parentID }) else { return }
            let parentPosition = nodes[parentIndex].position
            let offsetX = CGFloat.random(in: -50...50)
            let offsetY = CGFloat.random(in: -50...50)
            let newPosition = parentPosition + CGPoint(x: offsetX, y: offsetY)
            let newNode = AnyNode(Node(label: newLabel, position: newPosition))
            nodes.append(newNode)
            await addEdge(from: parentID, target: newNode.id, type: EdgeType.hierarchy) // Changed to EdgeType.hierarchy
        }

    public func deleteNode(withID id: NodeID) async {
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.target == id }
        objectWillChange.send()
        await startSimulation()
    }

    public func updateNodeContent(withID id: NodeID, newContent: NodeContent?) async {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            var updated = nodes[index].unwrapped
            updated.content = newContent
            nodes[index] = AnyNode(updated)
            objectWillChange.send()
        }
    }
}
