//
//  GraphModel+Helpers.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation
import os

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    private static let helpersLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "GraphEditorShared", category: "GraphModel.Helpers")

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
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else {
#if DEBUG
            if LogManager.verboseSimulationLogging {
                print("handleTap: Index not found for ID \(nodeID)")
            }
#endif
            return
        }
        let oldNode = nodes[index]
#if DEBUG
        if LogManager.verboseSimulationLogging {
            let oldIsExpanded = (oldNode.unwrapped as? Node)?.isExpanded
            print("handleTap: Pre-handlingTap - old isExpanded: \(oldIsExpanded?.description ?? "not Node")")
        }
#endif

        let updatedNode = oldNode.handlingTap()
#if DEBUG
        if LogManager.verboseSimulationLogging {
            let newIsExpanded = (updatedNode.unwrapped as? Node)?.isExpanded
            print("handleTap: Post-handlingTap - updated isExpanded: \(newIsExpanded?.description ?? "not Node")")
        }
#endif

        nodes[index] = updatedNode
#if DEBUG
        if LogManager.verboseSimulationLogging {
            let assignedIsExpanded = (nodes[index].unwrapped as? Node)?.isExpanded
            print("handleTap: Post-assignment - model.nodes[\(index)] isExpanded: \(assignedIsExpanded?.description ?? "not Node")")
        }
#endif

        let children = edges.filter { $0.from == nodeID && $0.type == EdgeType.hierarchy }.map { $0.target }

        if let node = updatedNode.unwrapped as? Node, node.isCollapsible {
#if DEBUG
            if LogManager.verboseSimulationLogging {
                print("handleTap: Entered if-let - collapsible node isExpanded: \(node.isExpanded)")
            }
#endif

            if node.isExpanded {
                // Expand → gently push children outward in a circle (prevents overlap)
                for childID in children {
                    guard let childIndex = nodes.firstIndex(where: { $0.id == childID }) else { continue }
                    var child = nodes[childIndex].unwrapped

                    let angle = CGFloat.random(in: 0..<CGFloat.pi * 2)
                    let distance = Constants.App.nodeModelRadius * 4
                    let offset = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)

                    child.position = node.position + offset
                    nodes[childIndex] = AnyNode(child)
                }
            } else {
                // Collapse → do nothing at all to positions
                // Hidden nodes remain fully active in physics → perfect hierarchical layout
            }

        } else {
#if DEBUG
            if LogManager.verboseSimulationLogging {
                print("handleTap: Node is not collapsible or cast failed")
            }
#endif
        }

        objectWillChange.send()
        let unwrappedNodes = nodes.map { $0.unwrapped }
        let updatedUnwrapped = physicsEngine.runSimulation(steps: 20, nodes: unwrappedNodes, edges: edges)
        nodes = updatedUnwrapped.map { AnyNode($0) }
#if DEBUG
        if LogManager.verboseSimulationLogging {
            let finalIsExpanded = (nodes[index].unwrapped as? Node)?.isExpanded
            print("handleTap: Post-simulation - model.nodes[\(index)] isExpanded: \(finalIsExpanded?.description ?? "not Node")")
        }
#endif
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
    
    public var centroid: CGPoint? {
        // Exclude control nodes from centroid calculation to keep camera centered on actual graph nodes
        let regularNodes = visibleNodes.filter { !($0 is ControlNode) }
        return GraphEditorShared.centroid(of: regularNodes)
    }
    
    public func sortChildren<ComparableValue: Comparable>(of nodeID: NodeID, by keyPath: KeyPath<any NodeProtocol, ComparableValue>) async {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }),
              let node = nodes[index].unwrapped as? Node else {
            // Skip if not Node type
            return
        }
        
        pushUndo()  // Allow undo of sorting
        let sortedOrder = node.children.sorted { childID1, childID2 in
            guard let node1 = nodes.first(where: { $0.id == childID1 })?.unwrapped,
                  let node2 = nodes.first(where: { $0.id == childID2 })?.unwrapped else {
                return false  // Stable sort if nodes missing
            }
            return node1[keyPath: keyPath] < node2[keyPath: keyPath]
        }
        
        let updated = node.with(childOrder: sortedOrder)
        nodes[index] = AnyNode(updated)
        objectWillChange.send()
        await resumeSimulation()  // Re-simulate for layout adjustments
    }
    
    // Add this to GraphModel+Helpers.swift to include color resets (and optionally call save() if needed)
    public func resetGraph() async {
        nodes.removeAll()
        edges.removeAll()
        nextNodeLabel = 1  // Reset label counter
        hierarchyEdgeColor = .blue  // Reset to default
        associationEdgeColor = .white  // Reset to default
        undoStack.removeAll()
        redoStack.removeAll()
        objectWillChange.send()
        do {
            try await saveGraph()  // Add this to persist the reset
        } catch {
            Self.helpersLogger.error("Failed to save after reset: \(String(describing: error), privacy: .public)")
        }
        await startSimulation()  // Or resume if needed
    }
    
    // In GraphModel+Helpers.swift (add to extension GraphModel)
    @MainActor
    public var boundingBox: CGRect {
        guard !nodes.isEmpty else { return .zero }
        let xside = nodes.map { $0.position.x }
        let yside = nodes.map { $0.position.y }
        let minX = xside.min() ?? 0
        let minY = yside.min() ?? 0
        let maxX = xside.max() ?? 0
        let maxY = yside.max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // In GraphModel+Helpers.swift (add to extension GraphModel)
    @MainActor
    public func centerGraph() {
        guard !nodes.isEmpty else { return }
        let centroid = nodes.reduce(CGPoint.zero) { acc, node in
            CGPoint(x: acc.x + node.position.x, y: acc.y + node.position.y)
        } / CGFloat(nodes.count)
        for iteration in nodes.indices {
            var updatedNode = nodes[iteration]
            updatedNode.position -= centroid
            nodes[iteration] = updatedNode
        }
        objectWillChange.send()
    }
    
    public func collapsibleNode(with id: NodeID?) -> Node? {
        guard let id else { return nil }
        let node = nodes.first(where: { $0.id == id })?.unwrapped as? Node
        return node?.isCollapsible == true ? node : nil
    }
    
    /// Recursively updates positions of hidden children in the subtree of a collapsed node.
    /// Call this after manually moving a parent during drag (when simulation is paused).
    public func updateSubtreePositions(for parentID: NodeID, to newParentPos: CGPoint) {
            guard let parentIndex = nodes.firstIndex(where: { $0.id == parentID }),
                  let node = nodes[parentIndex].unwrapped as? Node,
                  node.isCollapsible,
                  !node.isExpanded else {
                return  // Not a collapsed collapsible node; no-op
            }
            
            let children = edges
                .filter { $0.from == parentID && $0.type == .hierarchy }
                .map { $0.target }
            
            for (index, childID) in children.enumerated() {
                guard let childIndex = nodes.firstIndex(where: { $0.id == childID }) else { continue }
                
                let angle = CGFloat(index) * (2 * .pi / CGFloat(max(children.count, 1)))  // Avoid div-by-zero
                let jitterX = cos(angle) * 5.0  // Matches syncCollapsedPositions jitter
                let jitterY = sin(angle) * 5.0
                let newChildPos = newParentPos + CGPoint(x: jitterX, y: jitterY)
                
                var updatedChild = nodes[childIndex]
                updatedChild = AnyNode(updatedChild.unwrapped.with(position: newChildPos, velocity: .zero))
                nodes[childIndex] = updatedChild
                
                // Recurse for nested subtrees
                updateSubtreePositions(for: childID, to: newChildPos)
            }
            
            objectWillChange.send()  // Trigger UI update after batch mutations
        }
}
