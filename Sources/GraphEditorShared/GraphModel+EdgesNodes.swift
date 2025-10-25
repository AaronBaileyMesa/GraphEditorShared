//
//  GraphModel+EdgesNodes.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation
import os  // ADDED: For Logger

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    // NEW: Add static logger for this extension
    private static let logger = Logger.forCategory("graphmodel_edgesnodes")

    public func wouldCreateCycle(withNewEdgeFrom from: NodeID, target: NodeID, type: EdgeType) -> Bool {
        guard type == .hierarchy else { return false }
        var tempEdges = edges.filter { $0.type == .hierarchy }
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
            // CHANGED: Qualified static logger
            Self.logger.warning("Cannot add edge: Would create cycle in hierarchy")  // Replaced print with warning log
            return
        }
        pushUndo()
        edges.append(GraphEdge(from: from, target: target, type: type))
        objectWillChange.send()
        await resumeSimulation()
    }

    public func deleteEdge(withID id: UUID) async {
        // CHANGED: Qualified
        Self.logger.debugLog("Deleting edge with ID: \(id.uuidString.prefix(8))")  // Added debug log
        pushUndo()
        edges.removeAll { $0.id == id }
        objectWillChange.send()
        await resumeSimulation()
    }

    public func addNode(at position: CGPoint) async {
        // CHANGED: Qualified; manual CGPoint formatting
        Self.logger.debugLog("Adding node at position: x=\(position.x), y=\(position.y)")  // Added debug log
        pushUndo()
        let newLabel = nextNodeLabel
        nextNodeLabel += 1
        let newNode = AnyNode(Node(label: newLabel, position: position))
        nodes.append(newNode)
        objectWillChange.send()
        await resumeSimulation()
    }

    public func addToggleNode(at position: CGPoint) async {
        Self.logger.debugLog("Adding toggle node at position: x=\(position.x), y=\(position.y)")  // Added debug log
        pushUndo()
        let newLabel = nextNodeLabel
        nextNodeLabel += 1
        let newNode = AnyNode(ToggleNode(label: newLabel, position: position))
        nodes.append(newNode)
        objectWillChange.send()
        await resumeSimulation()
    }

    public func addChild(to parentID: NodeID) async {
        Self.logger.debugLog("Adding child to parent ID: \(parentID.uuidString.prefix(8))")  // Added debug log
        pushUndo()
        let newLabel = nextNodeLabel
        nextNodeLabel += 1
        guard let parentIndex = nodes.firstIndex(where: { $0.id == parentID }) else { return }
        let parentPosition = nodes[parentIndex].position
        let offsetX = CGFloat.random(in: -50...50)
        let offsetY = CGFloat.random(in: -50...50)
        let newPosition = parentPosition + CGPoint(x: offsetX, y: offsetY)
        let newNode = AnyNode(Node(label: newLabel, position: newPosition))  // Default to plain Node; could make configurable later
        nodes.append(newNode)
        edges.append(GraphEdge(from: parentID, target: newNode.id, type: .hierarchy))
        
        // NEW: If parent is ToggleNode, append to its children and childOrder
        if var parentToggle = nodes[parentIndex].unwrapped as? ToggleNode {
            if !parentToggle.children.contains(newNode.id) {  // Avoid duplicates
                parentToggle.children.append(newNode.id)
                parentToggle.childOrder.append(newNode.id)  // Append to maintain initial order
                nodes[parentIndex] = AnyNode(parentToggle)
            }
        }
        
        objectWillChange.send()
        await resumeSimulation()
    }

    public func deleteNode(withID id: NodeID) async {
        // CHANGED: Qualified
        Self.logger.debugLog("Deleting node with ID: \(id.uuidString.prefix(8))")  // Added debug log
        pushUndo()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.target == id }
        objectWillChange.send()
        await resumeSimulation()
    }

    public func updateNodeContents(withID id: NodeID, newContents: [NodeContent]) async {
        // CHANGED: Qualified
        Self.logger.debugLog("Updating contents for node ID: \(id.uuidString.prefix(8))")  // Added debug log
        pushUndo()
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            var updated = nodes[index].unwrapped
            updated.contents = newContents
            nodes[index] = AnyNode(updated)
            objectWillChange.send()
            await resumeSimulation()
        }
    }

    public func deleteSelected(selectedNodeID: NodeID?, selectedEdgeID: UUID?) async {
        // CHANGED: Qualified
        Self.logger.debugLog("Deleting selected: node=\(selectedNodeID?.uuidString.prefix(8) ?? "nil"), edge=\(selectedEdgeID?.uuidString.prefix(8) ?? "nil")")  // Added debug log
        pushUndo()
        if let id = selectedEdgeID {
            edges.removeAll { $0.id == id }
        } else if let id = selectedNodeID {
            nodes.removeAll { $0.id == id }
            edges.removeAll { $0.from == id || $0.target == id }
        }
        objectWillChange.send()
        await resumeSimulation()
    }

    public func toggleExpansion(for nodeID: NodeID) async {
        // CHANGED: Qualified
        Self.logger.debugLog("Toggling expansion for node ID: \(nodeID.uuidString.prefix(8))")  // Added debug log
        pushUndo()
        guard let idx = nodes.firstIndex(where: { $0.id == nodeID }), let toggle = nodes[idx].unwrapped as? ToggleNode else { return }
        let updated = toggle.handlingTap()
        nodes[idx] = AnyNode(updated)
        objectWillChange.send()
        await resumeSimulation()
    }
}
