//
//  GraphModel+Helpers.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    func buildAdjacencyList(for edgeType: EdgeType? = nil) -> [NodeID: [NodeID]] { 
        var adj = [NodeID: [NodeID]]()
        let filteredEdges = edgeType != nil ? edges.filter { $0.type == edgeType! } : edges
        for edge in filteredEdges {
            adj[edge.from, default: []].append(edge.target)
        }
        return adj
    }

    private func dfsVisible(node: any NodeProtocol, adjacency: [NodeID: [NodeID]], visited: inout Set<NodeID>, visible: inout [any NodeProtocol]) {
        visited.insert(node.id)
        visible.append(node)
        if !node.isExpanded { return }
        if let children = adjacency[node.id] {
            for childID in children {
                if !visited.contains(childID), let child = nodes.first(where: { $0.id == childID })?.unwrapped {
                    dfsVisible(node: child, adjacency: adjacency, visited: &visited, visible: &visible)
                }
            }
        }
    }

    public func isBidirectionalBetween(_ id1: NodeID, _ id2: NodeID) -> Bool {
        edges.contains(where: { $0.from == id1 && $0.target == id2 }) &&
        edges.contains(where: { $0.from == id2 && $0.target == id1 })
    }

    public func edgesBetween(_ id1: NodeID, _ id2: NodeID) -> [GraphEdge] {
        edges.filter { ($0.from == id1 && $0.target == id2) || ($0.from == id2 && $0.target == id1) }
    }

    public func handleTap(on nodeID: NodeID) async {
            guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
            let oldNode = nodes[index]
            let updatedNode = oldNode.handlingTap()
            nodes[index] = updatedNode

            let children = edges.filter { $0.from == nodeID && $0.type == EdgeType.hierarchy }.map { $0.target } // Changed to EdgeType.hierarchy
        
        if let toggleNode = updatedNode.unwrapped as? ToggleNode {
            if toggleNode.isExpanded {
                for childID in children {
                    guard let childIndex = nodes.firstIndex(where: { $0.id == childID }) else { continue }
                    var child = nodes[childIndex]
                    let offsetX = CGFloat.random(in: -Constants.App.nodeModelRadius * 3 ... Constants.App.nodeModelRadius * 3)
                    let offsetY = CGFloat.random(in: Constants.App.nodeModelRadius * 2 ... Constants.App.nodeModelRadius * 4)
                    child.position = toggleNode.position + CGPoint(x: offsetX, y: offsetY)
                    child.velocity = .zero
                    nodes[childIndex] = child
                }
                physicsEngine.temporaryDampingBoost(steps: Constants.Physics.maxSimulationSteps / 10)
            } else {
                for childID in children {
                    guard let childIndex = nodes.firstIndex(where: { $0.id == childID }) else { continue }
                    var child = nodes[childIndex]
                    child.position = toggleNode.position
                    child.velocity = .zero
                    nodes[childIndex] = child
                }
            }
        }

        objectWillChange.send()
        let unwrappedNodes = nodes.map { $0.unwrapped }
        let updatedUnwrapped = physicsEngine.runSimulation(steps: 20, nodes: unwrappedNodes, edges: edges)
        nodes = updatedUnwrapped.map { AnyNode($0) }
        await resumeSimulation()
    }

    public func graphDescription(selectedID: NodeID?, selectedEdgeID: UUID?) -> String {
        let edgeCount = edges.count
        let edgeWord = edgeCount == 1 ? "edge" : "edges"
        var desc = "Graph with \(nodes.count) nodes and \(edgeCount) directed \(edgeWord)."
        if let selectedEdgeID = selectedEdgeID, let selectedEdge = edges.first(where: { $0.id == selectedEdgeID }),
           let fromNode = nodes.first(where: { $0.id == selectedEdge.from })?.unwrapped,
           let toNode = nodes.first(where: { $0.id == selectedEdge.target })?.unwrapped {
            desc += " Directed edge from node \(fromNode.label) to node \(toNode.label) selected."
        } else if let selectedID = selectedID, let selectedNode = nodes.first(where: { $0.id == selectedID })?.unwrapped {
            let outgoingLabels = edges
                .filter { $0.from == selectedID }
                .compactMap { edge in
                    let targetID = edge.target
                    return nodes.first { $0.id == targetID }?.unwrapped.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            let incomingLabels = edges
                .filter { $0.target == selectedID }
                .compactMap { edge in
                    let fromID = edge.from
                    return nodes.first { $0.id == fromID }?.unwrapped.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            let outgoingText = outgoingLabels.isEmpty ? "none" : outgoingLabels
            let incomingText = incomingLabels.isEmpty ? "none" : incomingLabels
            desc += " Node \(selectedNode.label) selected, outgoing to: \(outgoingText); incoming from: \(incomingText)."
        } else {
            desc += " No node or edge selected."
        }
        return desc
    }
}
