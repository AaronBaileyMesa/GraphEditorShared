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
    fileprivate static let simulationLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "GraphEditorShared", category: "graphmodel_edgesnodes")
    
    @MainActor
    public func wouldCreateCycle(withNewEdgeFrom from: NodeID, target: NodeID, type: EdgeType) -> Bool {
        guard type == .hierarchy else { return false }
        
        // NEW: If target does not yet exist in the graph, adding a leaf cannot create a cycle
        if !nodes.contains(where: { $0.id == target }) {
            return false
        }
        
        var tempEdges = edges.filter { $0.type == .hierarchy }
        tempEdges.append(GraphEdge(from: from, target: target, type: type))
        return !isAcyclic(edges: tempEdges)
    }

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
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

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
    public func addEdge(from: NodeID, target: NodeID, type: EdgeType) async {
        if wouldCreateCycle(withNewEdgeFrom: from, target: target, type: type) {
            Self.logger.warning("Cannot add edge: Would create cycle in hierarchy")
            return
        }
        pushUndo()
        edges.append(GraphEdge(from: from, target: target, type: type))
        objectWillChange.send()
        invalidateHiddenNodesCache()
        
        // Only resume simulation if not in bulk operation mode
        if shouldDeferSimulation() {
            markSimulationNeeded()
        } else {
            await resumeSimulation()
        }
        await simulator.resetVelocityHistory()  
    }

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
    public func deleteEdge(withID id: UUID) async {
        // CHANGED: Qualified
        Self.logger.debugLog("Deleting edge with ID: \(id.uuidString.prefix(8))")  // Added debug log
        pushUndo()
        edges.removeAll { $0.id == id }
        objectWillChange.send()
        await resumeSimulation()
        invalidateHiddenNodesCache()
        await simulator.resetVelocityHistory()
    }

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
    public func addNode(at position: CGPoint) async -> AnyNode {
        pushUndo()
        let newLabel = nextNodeLabel
        nextNodeLabel += 1
        let node = Node(label: newLabel, position: position, isCollapsible: true)
        let anyNode = AnyNode(node)
        nodes.append(anyNode)
        objectWillChange.send()
        invalidateHiddenNodesCache()
        
        // Only resume simulation if not in bulk operation mode
        if shouldDeferSimulation() {
            markSimulationNeeded()
        } else {
            await resumeSimulation()
        }
        return anyNode
    }

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
    public func addToggleNode(at position: CGPoint) async {
        Self.logger.debugLog("Adding collapsible node at position: x=\(position.x), y=\(position.y)")
        pushUndo()
        let newLabel = nextNodeLabel
        nextNodeLabel += 1
        let newNode = AnyNode(Node(label: newLabel, position: position, isCollapsible: true))
        nodes.append(newNode)
        objectWillChange.send()
        await resumeSimulation()
    }

    @MainActor
    public func addPlainChild(to parentID: NodeID) async -> Bool {
        guard let parent = nodes.first(where: { $0.id == parentID })?.unwrapped as? Node,
              parent.isCollapsible else {
            Self.logger.warning("Cannot add plain child to non-collapsible parent \(parentID.uuidString.prefix(8))")
            return false
        }
        
        Self.logger.debugLog("Adding plain child to collapsible parent ID: \(parentID.uuidString.prefix(8))")
        await addChildInternal(to: parentID, createChild: { label, position in
            Node(label: label, position: position, isCollapsible: false)
        })
        return true
    }

    @MainActor
    public func addToggleChild(to parentID: NodeID) async -> Bool {
        guard let parent = nodes.first(where: { $0.id == parentID })?.unwrapped as? Node,
              parent.isCollapsible else {
            Self.logger.warning("Cannot add collapsible child to non-collapsible parent \(parentID.uuidString.prefix(8))")
            return false
        }
        
        await addChildInternal(to: parentID, createChild: { label, position in
            Node(label: label, position: position, isCollapsible: true)
        })
        return true
    }
    
    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
    // Private helper to avoid duplication (handles common logic like offsets, edges, and childOrder updates)
    private func addChildInternal(to parentID: NodeID, createChild: (Int, CGPoint) -> some NodeProtocol) async {
        pushUndo()
        let newLabel = nextNodeLabel
        nextNodeLabel += 1
        guard let parentIndex = nodes.firstIndex(where: { $0.id == parentID }) else { return }
        let parentPosition = nodes[parentIndex].position
        let offsetX = CGFloat.random(in: -50...50)  // Random for natural spread
        let offsetY = CGFloat.random(in: -50...50)
        let newPosition = CGPoint(x: parentPosition.x + offsetX, y: parentPosition.y + offsetY)
        
        // Create the child using the provided factory (leverages existing types)
        let child = createChild(newLabel, newPosition)
        let newNode = AnyNode(child)
        
        // Check for cycles before committing
        if wouldCreateCycle(withNewEdgeFrom: parentID, target: newNode.id, type: .hierarchy) {
            Self.logger.warning("Cannot add child: Would create cycle in hierarchy")
            return
        }
        
        nodes.append(newNode)
        edges.append(GraphEdge(from: parentID, target: newNode.id, type: .hierarchy))
        
        // Update parent: Add child to children list and childOrder
        let unwrappedParent = nodes[parentIndex].unwrapped
        if var parentNode = unwrappedParent as? Node {
            if !parentNode.children.contains(newNode.id) {  // Avoid duplicates
                parentNode.children.append(newNode.id)
                parentNode.childOrder.append(newNode.id)  // Append to maintain initial order
                nodes[parentIndex] = AnyNode(parentNode)  // Replace updated parent
            }
        } else {
            Self.logger.warning("Parent is not a Node type - cannot update children list")
        }
        
        objectWillChange.send()
        invalidateHiddenNodesCache()
        await resumeSimulation()
    }
    
    @MainActor
    public func deleteNode(withID id: NodeID) async {
        Self.logger.debugLog("Deleting node with ID: \(id.uuidString.prefix(8))")
        
        pushUndo()
        
        // Cleanup ephemerals and configs BEFORE removal (prevents dangling refs)
        ephemeralControlNodes.removeAll { $0.ownerID == id }
        ephemeralControlEdges.removeAll { $0.from == id || $0.target == id }
        uiConfig.removeValue(forKey: id)
        
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.target == id }
        
        objectWillChange.send()
        invalidateHiddenNodesCache()
        
        // Only resume simulation if not in bulk operation mode
        if shouldDeferSimulation() {
            markSimulationNeeded()
        } else {
            await resumeSimulation()
        }
        
        Self.logger.debugLog("Post-delete cleanup: Ephemerals left: \(ephemeralControlNodes.count), Configs left: \(uiConfig.count)")
    }
    
    // MARK: - Node Movement (drag & drop)
    @MainActor
    public func moveNode(withID nodeID: NodeID, to newPosition: CGPoint) async {
        Self.logger.debug("Moving node \(nodeID.uuidString.prefix(8)) → (\(newPosition.x), \(newPosition.y))")
        
        pushUndo()  // Always snapshot before mutation!
        
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else {
            Self.logger.warning("moveNode: Node not found – \(nodeID.uuidString.prefix(8))")
            return
        }
        
        var node = nodes[index].unwrapped
        node.position = newPosition
        node.velocity = .zero  // Stop any momentum
        
        nodes[index] = AnyNode(node)
        
        objectWillChange.send()
        invalidateHiddenNodesCache()
        await simulator.resetVelocityHistory()
        await resumeSimulation()
        
        // NEW: Auto-save after move
        do {
            try await saveGraph()
            Self.logger.info("Auto-saved graph after node move")
        } catch {
            Self.logger.error("Auto-save failed after move: \(error.localizedDescription)")
        }
        // FIXED: Manual string formatting for CGPoint
        Self.logger.debug("Updated position in model: (\(node.position.x), \(node.position.y))")
    }
    
    @MainActor
    public func moveNode(_ node: any NodeProtocol, to newPosition: CGPoint) async {
        await moveNode(withID: node.id, to: newPosition)
    }

    // MARK: - Node Duplication
    @MainActor
    public func duplicateNode(withID nodeID: NodeID) async -> NodeID? {
        Self.logger.debugLog("Duplicating node with ID: \(nodeID.uuidString.prefix(8))")

        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else {
            Self.logger.warning("duplicateNode: Node not found – \(nodeID.uuidString.prefix(8))")
            return nil
        }

        pushUndo()

        let originalNode = nodes[index].unwrapped
        let newLabel = nextNodeLabel
        nextNodeLabel += 1

        // Create duplicate with offset position
        let offsetX = CGFloat.random(in: 30...60)
        let offsetY = CGFloat.random(in: 30...60)
        let newPosition = CGPoint(
            x: originalNode.position.x + offsetX,
            y: originalNode.position.y + offsetY
        )

        // Create new node based on type, preserving contents and collapsibility
        let duplicateNode: AnyNode
        if let node = originalNode as? Node {
            let newNode = Node(
                label: newLabel,
                position: newPosition,
                isExpanded: node.isExpanded,
                isCollapsible: node.isCollapsible,
                contents: node.contents,
                children: [],  // Don't duplicate children - just the node itself
                childOrder: []
            )
            duplicateNode = AnyNode(newNode)
        } else {
            // Fallback for other node types
            var newNode = Node(
                label: newLabel,
                position: newPosition
            )
            newNode.contents = originalNode.contents
            duplicateNode = AnyNode(newNode)
        }

        nodes.append(duplicateNode)

        objectWillChange.send()
        invalidateHiddenNodesCache()
        // Don't auto-resume simulation - let caller handle it after selection
        // This prevents centroid shift before controls are regenerated

        Self.logger.debugLog("Created duplicate node with ID: \(duplicateNode.id.uuidString.prefix(8))")
        return duplicateNode.id
    }

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
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

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
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
        invalidateHiddenNodesCache()
        await resumeSimulation()
    }

    // ADDED: @MainActor to isolate this method to the main thread
    // GraphModel+EdgesNodes.swift  (or any extension — this one is already imported everywhere)

    @MainActor
    public func toggleExpansion(for nodeID: NodeID) async {
        Self.logger.debugLog("Toggling expansion for node ID: \(nodeID.uuidString.prefix(8))")
        
        pushUndo()  // Must come first — undo captures old state
        
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else {
            Self.logger.warning("toggleExpansion: Node not found – \(nodeID.uuidString.prefix(8))")
            return
        }
        
        // Must unwrap to a concrete Node to call handlingTap()
        guard var node = nodes[index].unwrapped as? Node else {
            Self.logger.warning("toggleExpansion: Node is not a Node type – \(nodeID.uuidString.prefix(8))")
            return
        }
        
        guard node.isCollapsible else {
            Self.logger.warning("toggleExpansion: Node is not collapsible – \(nodeID.uuidString.prefix(8))")
            return
        }
        
        node = node.handlingTap()           // toggles isExpanded + zeros velocity
        nodes[index] = AnyNode(node)        // write back
        
        objectWillChange.send()
        
        invalidateHiddenNodesCache()
        
        await simulator.resetVelocityHistory()
        await resumeSimulation()
    }
    
    @MainActor
    public func toggleNodeCollapsibility(nodeID: NodeID) async {
        Self.logger.debugLog("Toggling collapsibility for node ID: \(nodeID.uuidString.prefix(8))")
        
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else {
            Self.logger.warning("toggleNodeCollapsibility: Node not found – \(nodeID.uuidString.prefix(8))")
            return
        }
        
        guard var node = nodes[index].unwrapped as? Node else {
            Self.logger.warning("toggleNodeCollapsibility: Node is not a Node type – \(nodeID.uuidString.prefix(8))")
            return
        }
        
        // Prevent making node non-collapsible if it has children
        if node.isCollapsible && !node.children.isEmpty {
            Self.logger.warning("toggleNodeCollapsibility: Cannot make node non-collapsible while it has children – \(nodeID.uuidString.prefix(8))")
            return
        }
        
        pushUndo()
        
        // Toggle the collapsibility flag
        let newCollapsibility = !node.isCollapsible
        node.isCollapsible = newCollapsibility
        
        // If making non-collapsible, ensure it's expanded
        if !newCollapsibility {
            node.isExpanded = true
        }
        
        nodes[index] = AnyNode(node)
        
        objectWillChange.send()
        invalidateHiddenNodesCache()
        await simulator.resetVelocityHistory()
        await resumeSimulation()
        
        Self.logger.info("Node \(nodeID.uuidString.prefix(8)) collapsibility: \(node.isCollapsible)")
    }
}
