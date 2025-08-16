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
    @Published public var nodes: [any NodeProtocol] = []
    @Published public var edges: [GraphEdge] = []

    @Published public var isSimulating: Bool = false
    private var simulationTimer: Timer? = nil
    
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    public var nextNodeLabel = 1  // Internal for testability; auto-increments node labels
    
    private let storage: GraphStorage
    public let physicsEngine: PhysicsEngine  // Changed to public
    
    private lazy var simulator: GraphSimulator = {
        GraphSimulator(
            getNodes: { [weak self] in self?.nodes ?? [] },
            setNodes: { [weak self] nodes in self?.nodes = nodes },
            getEdges: { [weak self] in self?.edges ?? [] },
            
            getVisibleNodes: { [weak self] in self?.visibleNodes() ?? [] },
            getVisibleEdges: { [weak self] in self?.visibleEdges() ?? [] },
            
            physicsEngine: self.physicsEngine,
            onStable: { [weak self] in
                guard let self = self else { return }
                var centeredNodes = self.physicsEngine.centerNodes(nodes: self.nodes)
                // New: Reset velocities to prevent re-triggering simulation
                centeredNodes = centeredNodes.map { node in
                    node.with(position: node.position, velocity: .zero)
                }
                self.nodes = centeredNodes
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
        
        var tempNodes: [any NodeProtocol] = []
        var tempEdges: [GraphEdge] = []
        var tempNextLabel = nextNodeLabel ?? 1
        
        do {
            let loaded = try storage.load()
            tempNodes = loaded.nodes
            tempEdges = loaded.edges
            tempNextLabel = (tempNodes.map { $0.label }.max() ?? 0) + 1
        } catch {
            os_log("Load failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            // Proceed with defaults below
        }
        
        if tempNodes.isEmpty && tempEdges.isEmpty {
            (tempNodes, tempEdges, tempNextLabel) = Self.createDefaultGraph(startingLabel: tempNextLabel)
            do {
                try storage.save(nodes: tempNodes, edges: tempEdges)
            } catch {
                os_log("Save defaults failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            }
        }
        
        self.nodes = tempNodes
        self.edges = tempEdges
        self.nextNodeLabel = tempNextLabel  // Always set (computed above)
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
    private static func createDefaultGraph(startingLabel: Int) -> ([any NodeProtocol], [GraphEdge], Int) {
        let defaultNodes: [Node] = [
            Node(label: startingLabel, position: CGPoint(x: 100, y: 100)),
            Node(label: startingLabel + 1, position: CGPoint(x: 200, y: 200)),
            Node(label: startingLabel + 2, position: CGPoint(x: 150, y: 300))
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
        let state = GraphState(nodes: nodes, edges: edges)
        undoStack.append(state)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        do {
            try storage.save(nodes: nodes, edges: edges)
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
        let current = GraphState(nodes: nodes, edges: edges)
        redoStack.append(current)
        let previous = undoStack.removeLast()
        nodes = previous.nodes
        edges = previous.edges
        self.physicsEngine.resetSimulation()  // Ready for new simulation
#if os(watchOS)
        WKInterfaceDevice.current().play(.click)
#endif
        do {
            try storage.save(nodes: nodes, edges: edges)
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
        let current = GraphState(nodes: nodes, edges: edges)
        undoStack.append(current)
        let next = redoStack.removeLast()
        nodes = next.nodes
        edges = next.edges
        self.physicsEngine.resetSimulation()  // Ready for new simulation
#if os(watchOS)
        WKInterfaceDevice.current().play(.click)
#endif
        do {
            try storage.save(nodes: nodes, edges: edges)
        } catch {
            os_log("Failed to save after redo: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func saveGraph() {
        do {
            try storage.save(nodes: nodes, edges: edges)
        } catch {
            os_log("Failed to save graph: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func deleteNode(withID id: NodeID) {
        snapshot()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
        self.physicsEngine.resetSimulation()
    }
    
    public func deleteSelectedEdge(id: UUID?) {
        guard let id = id else { return }
        snapshot()
        edges.removeAll { $0.id == id }
        self.physicsEngine.resetSimulation()
        startSimulation()
    }
    
    public func addNode(at position: CGPoint) {
        if nodes.count >= 100 {
            return
        }
        let newNode = Node(label: nextNodeLabel, position: position, radius: 10.0)
        nodes.append(newNode)
        nextNodeLabel += 1
        let centeredNodes = physicsEngine.centerNodes(nodes: nodes)
        nodes = centeredNodes
        self.physicsEngine.resetSimulation()
    }
    
    public func updateNode(_ updatedNode: any NodeProtocol) {
        if let index = nodes.firstIndex(where: { $0.id == updatedNode.id }) {
            nodes[index] = updatedNode
            objectWillChange.send()  // Ensure views refresh
            startSimulation()  // Optional: Restart sim if toggle affects layout
        }
    }
    
    public func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) throws {
        try storage.saveViewState(offset: offset, zoomScale: zoomScale, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
    }

    public func loadViewState() throws -> (offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?)? {
        try storage.loadViewState()
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
    public func visibleNodes() -> [any NodeProtocol] {
        var visible: [any NodeProtocol] = []
        var visited = Set<NodeID>()
        let adjacency = buildAdjacencyList()
        let roots = buildRoots()
        for root in roots {
            if !visited.contains(root.id) {
                dfsVisible(node: root, adjacency: adjacency, visited: &visited, visible: &visible)
            }
        }
        return visible
    }
    
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
    
    public func visibleEdges() -> [GraphEdge] {
        let visibleIDs = Set(visibleNodes().map { $0.id })
        return edges.filter { visibleIDs.contains($0.from) && visibleIDs.contains($0.to) }
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
    
    public func addToggleNode(at position: CGPoint) {
        nodes.append(ToggleNode(label: nextNodeLabel, position: position))
        nextNodeLabel += 1
        if nodes.count >= 100 { return }
        physicsEngine.resetSimulation()
    }
    
    // In GraphModel.swift, replace the existing addChild with this:
    public func addChild(to parentID: NodeID, at position: CGPoint? = nil, isToggle: Bool = false) {
        guard let parent = nodes.first(where: { $0.id == parentID }) else { return }
        let childPosition = position ?? CGPoint(x: parent.position.x + 50, y: parent.position.y + 50)
        let childLabel = nextNodeLabel
        nextNodeLabel += 1
        
        let child: any NodeProtocol = isToggle ?
        ToggleNode(label: childLabel, position: childPosition) :
        Node(label: childLabel, position: childPosition)
        
        nodes.append(child)
        let newEdge = GraphEdge(from: parentID, to: child.id)
        
        // Check for cycles before adding edge
        if hasCycle(adding: newEdge) {
            // Optionally: Log or alert user
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
