// Sources/GraphEditorShared/GraphModel.swift

import os.log
import SwiftUI
import Combine
import Foundation

#if os(watchOS)
import WatchKit
#endif

private let logger = OSLog(subsystem: "io.handcart.GraphEditor", category: "storage")

@available(iOS 13.0, watchOS 6.0, *)
public class GraphModel: ObservableObject {
    @Published public var nodes: [AnyNode] = []  // Changed to [AnyNode] for Equatable conformance
    @Published public var edges: [GraphEdge] = []
    @Published public var isSimulating: Bool = false
           
    private var simulationTimer: Timer? = nil
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    public var nextNodeLabel = 1  // Internal for testability; auto-increments node labels
    
    private let storage: GraphStorage
    public let physicsEngine: PhysicsEngine  // Changed to public
    private var hiddenNodeIDs: Set<NodeID> {
        var hidden = Set<NodeID>()
        var toHide: [NodeID] = []

        // Seed with direct children of collapsed toggle nodes
        for node in nodes {
            if node.unwrapped.shouldHideChildren() {
                let children = edges.filter { $0.from == node.id }.map { $0.to }
                toHide.append(contentsOf: children)
            }
        }

        // Iteratively hide all descendants (DFS)
        while !toHide.isEmpty {
            let current = toHide.removeLast()
            if hidden.insert(current).inserted {
                let children = edges.filter { $0.from == current }.map { $0.to }
                toHide.append(contentsOf: children)
            }
        }

        return hidden
    }
    
        private lazy var simulator: GraphSimulator = {
        GraphSimulator(
            getNodes: { [weak self] in self?.nodes.map { $0.unwrapped } ?? [] },  // Map to [any NodeProtocol]
            setNodes: { [weak self] newNodes in
                self?.nodes = newNodes.map { AnyNode($0) }  // Wrap incoming as [AnyNode]
            },
            getEdges: { [weak self] in self?.edges ?? [] },
            
            getVisibleNodes: { [weak self] in self?.visibleNodes() ?? [] },
            getVisibleEdges: { [weak self] in self?.visibleEdges() ?? [] },
            
            physicsEngine: self.physicsEngine,
            onStable: { [weak self] in
                guard let self = self else { return }
                print("Simulation stable: Centering nodes")  // Debug
                let centeredNodes = self.physicsEngine.centerNodes(nodes: self.nodes.map { $0.unwrapped })  // Unwrap for physics, re-wrap below
                // New: Reset velocities to prevent re-triggering simulation
                self.nodes = centeredNodes.map { AnyNode($0.with(position: $0.position, velocity: .zero)) }
                self.objectWillChange.send()
            }
        )
    }()
    
    // Indicates if undo is possible.
    public var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    // Indicates if redo is possible.
    public var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    // Single initializer with optional nextNodeLabel for testing.
    public init(storage: GraphStorage = PersistenceManager(), physicsEngine: PhysicsEngine, nextNodeLabel: Int? = nil) {
        self.storage = storage
        self.physicsEngine = physicsEngine
        
        var tempNodes: [AnyNode] = []
        var tempEdges: [GraphEdge] = []
        var tempNextLabel = nextNodeLabel ?? 1
        
        do {
            let loaded = try storage.load()
            tempNodes = loaded.nodes.map { AnyNode($0) }  // Wrap loaded nodes as AnyNode
            tempEdges = loaded.edges
            tempNextLabel = (tempNodes.map { $0.label }.max() ?? 0) + 1
        } catch {
            os_log("Load failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            // Proceed with defaults below
        }
        
        if tempNodes.isEmpty && tempEdges.isEmpty {
            (tempNodes, tempEdges, tempNextLabel) = Self.createDefaultGraph(startingLabel: tempNextLabel)
            do {
                try storage.save(nodes: tempNodes.map { $0.unwrapped }, edges: tempEdges)  // Unwrap for save
            } catch {
                os_log("Save defaults failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            }
        }
        
        self.nodes = tempNodes
        self.edges = tempEdges
        self.nextNodeLabel = tempNextLabel  // Always set (computed above without duplication)
    }

    public func clearGraph() {
        snapshot()
        nodes = []
        edges = []
        nextNodeLabel = 1  // Explicit reset
        physicsEngine.resetSimulation()
        startSimulation()
        try? storage.clear()
    }
    
    // Static factory for default graph creation.
    private static func createDefaultGraph(startingLabel: Int) -> ([AnyNode], [GraphEdge], Int) {
        let defaultNodes: [AnyNode] = [
            AnyNode(Node(label: startingLabel, position: CGPoint(x: 100, y: 100))),
            AnyNode(Node(label: startingLabel + 1, position: CGPoint(x: 200, y: 200))),
            AnyNode(Node(label: startingLabel + 2, position: CGPoint(x: 150, y: 300)))
        ]
        let defaultEdges: [GraphEdge] = [
            GraphEdge(from: defaultNodes[0].id, to: defaultNodes[1].id),
            GraphEdge(from: defaultNodes[1].id, to: defaultNodes[2].id),
            GraphEdge(from: defaultNodes[2].id, to: defaultNodes[0].id)
        ]
        return (defaultNodes, defaultEdges, startingLabel + 3)
    }
    
    // Creates a snapshot of the current state for undo/redo and saves.
    public func snapshot() {
        let state = GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges)  // Unwrap for state (keep storage light)
        undoStack.append(state)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        do {
            try storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            os_log("Failed to save snapshot: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    // Undoes the last action if possible, with haptic feedback.
    public func undo() {
        guard !undoStack.isEmpty else {
#if os(watchOS)
            WKInterfaceDevice.current().play(.failure)
#endif
            return
        }
        let current = GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges)
        redoStack.append(current)
        let previous = undoStack.removeLast()
        nodes = previous.nodes.map { AnyNode($0) }  // Wrap on load
        edges = previous.edges
        self.physicsEngine.resetSimulation()  // Ready for new simulation
#if os(watchOS)
        WKInterfaceDevice.current().play(.click)
#endif
        do {
            try storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            os_log("Failed to save after undo: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func redo() {
        guard !redoStack.isEmpty else {
#if os(watchOS)
            WKInterfaceDevice.current().play(.failure)
#endif
            return
        }
        let current = GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges)
        undoStack.append(current)
        let next = redoStack.removeLast()
        nodes = next.nodes.map { AnyNode($0) }
        edges = next.edges
        self.physicsEngine.resetSimulation()
#if os(watchOS)
        WKInterfaceDevice.current().play(.click)
#endif
        do {
            try storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            os_log("Failed to save after redo: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func visibleNodes() -> [any NodeProtocol] {
        let hidden = hiddenNodeIDs
        return nodes.map { $0.unwrapped }.filter { $0.isVisible && !hidden.contains($0.id) }
    }

    public func visibleEdges() -> [GraphEdge] {
        let hidden = hiddenNodeIDs
        return edges.filter { !hidden.contains($0.from) && !hidden.contains($0.to) }
    }
    
    public func addNode(at position: CGPoint) {
        snapshot()
        let newNode = Node(label: nextNodeLabel, position: position, content: nil)  // Defaults for id, velocity, radius        nextNodeLabel += 1
        physicsEngine.resetSimulation()
        startSimulation()
    }
    
    // Add this public save method (if truncated/missing; place after resumeSimulation)
    public func save() {
        do {
            try storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            os_log("Failed to save graph: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func addToggleNode(at position: CGPoint) {
        snapshot()
        let newNode = AnyNode(ToggleNode(label: nextNodeLabel, position: position))
        nodes.append(newNode)
        nextNodeLabel += 1
        physicsEngine.resetSimulation()
        startSimulation()
    }
    
    public func updateNodeContent(withID id: NodeID, newContent: NodeContent?) {
        snapshot()
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].content = newContent
            objectWillChange.send()
            save()
        }
    }
    
    public func updateNode(_ updatedNode: any NodeProtocol) {
        if let index = nodes.firstIndex(where: { $0.id == updatedNode.id }) {
            let existingContent = nodes[index].content  // Preserve if not in updated
            nodes[index] = AnyNode(updatedNode)
            nodes[index].content = existingContent
            objectWillChange.send()
        }
    }
    
    public func deleteNode(withID id: NodeID) {
        snapshot()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
        physicsEngine.resetSimulation()  // If exists; else remove
        startSimulation()
        save()
    }
      public func deleteEdge(withID id: UUID) {
        snapshot()
        edges.removeAll { $0.id == id }
        startSimulation()
        save()
    }
    
    public func addChild(to parentID: NodeID, isToggle: Bool = false) {
        snapshot()
        guard let parent = nodes.first(where: { $0.id == parentID }) else { return }
        let childLabel = nextNodeLabel
        nextNodeLabel += 1
        let childPosition = parent.position + CGPoint(x: CGFloat.random(in: 50...100), y: CGFloat.random(in: 50...100))
        
        let child = isToggle ?
            AnyNode(ToggleNode(label: childLabel, position: childPosition)) :
            AnyNode(Node(label: childLabel, position: childPosition))
        
        nodes.append(child)
        let newEdge = GraphEdge(from: parentID, to: child.id)
        
        // Check for cycles before adding edge
        if hasCycle(adding: newEdge) {
            print("Cycle detected; edge not added.")
            return
        }
        
        edges.append(newEdge)
        physicsEngine.resetSimulation()
        startSimulation()
    }
    
    // Add this new helper function at the bottom of GraphModel (e.g., after resumeSimulation):
    public func hasCycle(adding edge: GraphEdge) -> Bool {
        var adj = buildAdjacencyList()
        adj[edge.from, default: []].append(edge.to)
        
        // DFS cycle detection from new edge's from-node
        var visited = Set<NodeID>()
        var recStack = Set<NodeID>()
        
        func dfs(_ node: NodeID) -> Bool {
            visited.insert(node)
            recStack.insert(node)
            if let neighbors = adj[node] {
                for neighbor in neighbors {
                    if !visited.contains(neighbor) {
                        if dfs(neighbor) { return true }
                    } else if recStack.contains(neighbor) {
                        return true
                    }
                }
            }
            recStack.remove(node)
            return false
        }
        
        return dfs(edge.from)
    }
    
    // Added: Public method to load graph from storage (avoids direct private access)
    public func loadFromStorage() throws {
        let loaded = try storage.load()
        nodes = loaded.nodes.map { AnyNode($0) }  // Wrap as AnyNode
        edges = loaded.edges
        nextNodeLabel = (nodes.map { $0.label }.max() ?? 0) + 1
        objectWillChange.send()
    }
    
    // Added: Public wrappers for view state (delegate to storage)
    public func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) throws {
        try storage.saveViewState(offset: offset, zoomScale: zoomScale, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
    }
    
    public func loadViewState() throws -> (offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?)? {
        try storage.loadViewState()
    }
    
    public func expandAllRoots() {
        // If visible nodes are empty but nodes exist, expand all ToggleNodes to ensure visibility.
        // This handles cycles/hierarchies where "roots" may not exist.
        if !nodes.isEmpty && visibleNodes().isEmpty {
            nodes = nodes.map { node in
                if let toggle = node.unwrapped as? ToggleNode {  // Unwrap to check type
                    var updatedToggle = toggle
                    updatedToggle.isExpanded = true
                    return AnyNode(updatedToggle)
                } else {
                    return node
                }
            }
            // Trigger simulation to reposition after expansion
            startSimulation()
            print("Expanded all ToggleNodes; visible nodes now: \(visibleNodes().count)")  // Debug log (remove later)
        }
    }
    
    private func incomingEdges(for id: NodeID) -> [GraphEdge] {
        edges.filter { $0.to == id }
    }
    
    public func centerGraph(around center: CGPoint? = nil) {
        guard !nodes.isEmpty else { return }
        let oldCentroid = centroid(of: nodes.map { $0.unwrapped }) ?? .zero  // Unwrap for centroid func if needed
        let targetCenter = center ?? CGPoint(x: physicsEngine.simulationBounds.width / 2, y: physicsEngine.simulationBounds.height / 2)
        let shift = targetCenter - oldCentroid
        print("Centering graph: Old centroid \(oldCentroid), Shift \(shift), New target \(targetCenter)")  // Debug
        
        nodes = nodes.map { $0.with(position: $0.position + shift, velocity: .zero) }  // with() returns AnyNode
        objectWillChange.send()
    }
    
    
    public func startSimulation() {
#if os(watchOS)
        guard WKApplication.shared().applicationState == .active else {
            return  // Don't simulate if backgrounded
        }
#endif
        simulator.startSimulation { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    public func stopSimulation() {
        simulator.stopSimulation()
    }

    public func pauseSimulation() {
        stopSimulation()
        physicsEngine.isPaused = true  // Assumes isPaused var in PhysicsEngine
    }
    
    public func resumeSimulation() {
        physicsEngine.isPaused = false
        startSimulation()
    }
    
    
    public func boundingBox() -> CGRect {
        self.physicsEngine.boundingBox(nodes: nodes)
    }
    
    

    private func buildRoots() -> [any NodeProtocol] {
        var incoming = Set<NodeID>()
        for edge in edges {
            incoming.insert(edge.to)
        }
        return nodes.filter { !incoming.contains($0.id) }
    }
    // Visibility methods

    private func dfsVisible(node: any NodeProtocol, adjacency: [NodeID: [NodeID]], visited: inout Set<NodeID>, visible: inout [any NodeProtocol]) {
        visited.insert(node.id)
        visible.append(node)  // Always append (even if collapsed)
        if !node.isExpanded { return }
        if let children = adjacency[node.id] {
            for childID in children {
                if !visited.contains(childID), let child = nodes.first(where: { $0.id == childID }) {
                    dfsVisible(node: child, adjacency: adjacency, visited: &visited, visible: &visible)
                }
            }
        }
    }
    

    public func isBidirectionalBetween(_ id1: NodeID, _ id2: NodeID) -> Bool {
        edges.contains { $0.from == id1 && $0.to == id2 } &&
        edges.contains { $0.from == id2 && $0.to == id1 }
    }
    
    public func edgesBetween(_ id1: NodeID, _ id2: NodeID) -> [GraphEdge] {
        edges.filter { ($0.from == id1 && $0.to == id2) || ($0.from == id2 && $0.to == id1) }
    }
    
    private func buildAdjacencyList() -> [NodeID: [NodeID]] {
        var adj = [NodeID: [NodeID]]()
        for edge in edges {
            adj[edge.from, default: []].append(edge.to)
        }
        return adj
    }
    
    // Add this new helper function at the bottom of GraphModel (e.g., after resumeSimulation):

    // Added: Public method to load graph from storage (avoids direct private access)

    // Added: Public wrappers for view state (delegate to storage)
    
    

    

}

@available(iOS 13.0, watchOS 6.0, *)
extension GraphModel {
    
    public func graphDescription(selectedID: NodeID?, selectedEdgeID: UUID?) -> String {
        let edgeCount = edges.count
        let edgeWord = edgeCount == 1 ? "edge" : "edges"  // New: Handle plural
        var desc = "Graph with \(nodes.count) nodes and \(edgeCount) directed \(edgeWord)."
        if let selectedEdgeID = selectedEdgeID, let selectedEdge = edges.first(where: { $0.id == selectedEdgeID }),
           let fromNode = nodes.first(where: { $0.id == selectedEdge.from }),
           let toNode = nodes.first(where: { $0.id == selectedEdge.to }) {
            desc += " Directed edge from node \(fromNode.label) to node \(toNode.label) selected."
        } else if let selectedID = selectedID, let selectedNode = nodes.first(where: { $0.id == selectedID }) {
            let outgoingLabels = edges
                .filter { $0.from == selectedID }
                .compactMap { edge in
                    let toID = edge.to
                    return nodes.first { $0.id == toID }?.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            let incomingLabels = edges
                .filter { $0.to == selectedID }
                .compactMap { edge in
                    let fromID = edge.from
                    return nodes.first { $0.id == fromID }?.label
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
