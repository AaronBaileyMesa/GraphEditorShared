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
@MainActor public class GraphModel: ObservableObject {
    @Published public var nodes: [AnyNode] = []  // Changed to [AnyNode] for Equatable conformance
    @Published public var edges: [GraphEdge] = []
    @Published public var isSimulating: Bool = false
    @Published public var isStable: Bool = false  // New: Added for onReceive
    @Published public var simulationError: Error? = nil  // New: Added for onReceive
           
    private var simulationTimer: Timer? = nil
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    public var nextNodeLabel = 1  // Internal for testability; auto-increments node labels
    
    private let storage: GraphStorage
    public var physicsEngine: PhysicsEngine  // Changed to var to allow recreation
    
    private var hiddenNodeIDs: Set<NodeID> {
        var hidden = Set<NodeID>()
        var toHide: [NodeID] = []

        // Seed with direct children of collapsed toggle nodes, but only via .hierarchy edges
        for node in nodes {
            if node.unwrapped.shouldHideChildren() {
                let children = edges.filter { $0.from == node.id && $0.type == .hierarchy }.map { $0.to }
                toHide.append(contentsOf: children)
            }
        }

        // Iteratively hide all descendants (DFS), only along .hierarchy edges
        let adj = buildAdjacencyList(for: .hierarchy)  // Filter by type
        while !toHide.isEmpty {
            let current = toHide.removeLast()
            if hidden.insert(current).inserted {
                let children = adj[current] ?? []
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
                self.isStable = true  // New: Set isStable on stable
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
        self.nodes = []  // Start empty; load async later
        self.edges = []
        self.nextNodeLabel = nextNodeLabel ?? 1
        Task { try? await loadFromStorage() }  // Fire async load; ignore errors for init
    }

    public func loadFromStorage() async throws {
        let loaded = try await storage.load()
        nodes = loaded.nodes.map { AnyNode($0) }
        edges = loaded.edges
        objectWillChange.send()
        await resizeSimulationBounds(for: nodes.count)  // New: Make async call
    }

    // Added: Missing visibleNodes and visibleEdges from errors
    public func visibleNodes() -> [any NodeProtocol] {
        let hidden = hiddenNodeIDs
        return nodes.filter { !hidden.contains($0.id) }.map { $0.unwrapped }
    }
    
    public func visibleEdges() -> [GraphEdge] {
        let hidden = hiddenNodeIDs
        return edges.filter { !hidden.contains($0.from) && !hidden.contains($0.to) }
    }

    // New: Method to dynamically resize simulation bounds based on node count (now async)
    public func resizeSimulationBounds(for nodeCount: Int) async {
        let newSize = max(300.0, sqrt(Double(nodeCount)) * 100.0)  // Grows with sqrt(nodes), e.g., 100 nodes -> ~1000
        self.physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: newSize, height: newSize))  // Recreate with new bounds
        // Recreate simulator to capture new physicsEngine
        self.simulator = GraphSimulator(
            getNodes: { [weak self] in self?.nodes.map { $0.unwrapped } ?? [] },
            setNodes: { [weak self] newNodes in
                self?.nodes = newNodes.map { AnyNode($0) }
            },
            getEdges: { [weak self] in self?.edges ?? [] },
            getVisibleNodes: { [weak self] in self?.visibleNodes() ?? [] },
            getVisibleEdges: { [weak self] in self?.visibleEdges() ?? [] },
            physicsEngine: self.physicsEngine,
            onStable: { [weak self] in
                guard let self = self else { return }
                print("Simulation stable: Centering nodes")
                let centeredNodes = self.physicsEngine.centerNodes(nodes: self.nodes.map { $0.unwrapped })
                self.nodes = centeredNodes.map { AnyNode($0.with(position: $0.position, velocity: .zero)) }
                self.isStable = true
                self.objectWillChange.send()
            }
        )
    }

    // New: Cycle check method (filters by .hierarchy)
    public func wouldCreateCycle(withNewEdgeFrom from: NodeID, to: NodeID, type: EdgeType) -> Bool {
        guard type == .hierarchy else { return false }  // No check for .association
        var tempEdges = edges.filter { $0.type == .hierarchy }  // Filter existing .hierarchy
        tempEdges.append(GraphEdge(from: from, to: to, type: type))
        return !isAcyclic(edges: tempEdges)
    }

    private func isAcyclic(edges: [GraphEdge]) -> Bool {
        // Build adjacency list from filtered edges
        var adj: [NodeID: [NodeID]] = [:]
        var inDegree: [NodeID: Int] = [:]
        nodes.forEach { inDegree[$0.id] = 0 }
        for edge in edges {
            adj[edge.from, default: []].append(edge.to)
            inDegree[edge.to, default: 0] += 1
        }
        // Kahn's algorithm
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
        return count == nodes.count  // Acyclic if all nodes processed
    }

    // New/Updated: Add edge with type and cycle check
    public func addEdge(from: NodeID, to: NodeID, type: EdgeType) async {
        if wouldCreateCycle(withNewEdgeFrom: from, to: to, type: type) {
            print("Cannot add edge: Would create cycle in hierarchy")
            return  // Reject if cycle in .hierarchy
        }
        edges.append(GraphEdge(from: from, to: to, type: type))
        objectWillChange.send()
        await startSimulation()
    }
    
    public func boundingBox() -> CGRect {
        self.physicsEngine.boundingBox(nodes: nodes.map { $0.unwrapped })
    }
    
    // Added: Stub for centerGraph based on errors (enhance as needed)
    public func centerGraph() {
        let centered = physicsEngine.centerNodes(nodes: nodes.map { $0.unwrapped })
        nodes = centered.map { AnyNode($0) }
        objectWillChange.send()
    }
    
    // Added: Stub for expandAllRoots (implement based on your logic)
    public func expandAllRoots() async {
        for var root in buildRoots() {
            root.isExpanded = true
            // Update in nodes array
            if let index = nodes.firstIndex(where: { $0.id == root.id }) {
                nodes[index] = AnyNode(root)
            }
        }
        objectWillChange.send()
    }
    
    // Added: Stubs for other missing methods from errors
    public func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) throws {
        // Implement saving logic here
    }
    
    public func loadViewState() throws -> (offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?)? {
        // Implement loading logic here
        return nil  // Placeholder
    }
    
    public func snapshot() async {
        // Implement snapshot for undo/redo
        let state = GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges)
        undoStack.append(state)
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack.removeAll()
    }
    
    public func undo() async {
        guard let state = undoStack.popLast() else { return }
        redoStack.append(GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges))
        nodes = state.nodes.map { AnyNode($0) }
        edges = state.edges
        objectWillChange.send()
    }
    
    public func redo() async {
        guard let state = redoStack.popLast() else { return }
        undoStack.append(GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges))
        nodes = state.nodes.map { AnyNode($0) }
        edges = state.edges
        objectWillChange.send()
    }
    
    public func clearGraph() async {
        nodes = []
        edges = []
        nextNodeLabel = 1
        objectWillChange.send()
        await startSimulation()
    }
    
    public func deleteNode(withID id: NodeID) async {
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
        objectWillChange.send()
        await startSimulation()
    }
    
    public func deleteEdge(withID id: UUID) async {
        edges.removeAll { $0.id == id }
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
            let newPosition = CGPoint(x: CGFloat.random(in: -50...50), y: CGFloat.random(in: -50...50))  // Random near parent
            let newNode = AnyNode(Node(label: newLabel, position: newPosition))
            nodes.append(newNode)
            await addEdge(from: parentID, to: newNode.id, type: .hierarchy)  // Use .hierarchy
        }

        // Updated: buildAdjacencyList with optional type filter
        private func buildAdjacencyList(for edgeType: EdgeType? = nil) -> [NodeID: [NodeID]] {
            var adj = [NodeID: [NodeID]]()
            let filteredEdges = edgeType != nil ? edges.filter { $0.type == edgeType! } : edges
            for edge in filteredEdges {
                adj[edge.from, default: []].append(edge.to)
            }
            return adj
        }
    
    public func addNode(at position: CGPoint) async {
        let newLabel = nextNodeLabel
        nextNodeLabel += 1
        let newNode = AnyNode(Node(label: newLabel, position: position))
        nodes.append(newNode)
        objectWillChange.send()
        await startSimulation()
    }
    
    public func startSimulation() async {
        isStable = false  // Reset on start
        simulationError = nil  // Clear error
        isSimulating = true
        await simulator.startSimulation()  // No do-catch since non-throwing
        isSimulating = false
    }
    
    public func stopSimulation() async {
        await simulator.stopSimulation()
    }

    public func pauseSimulation() async {
        await stopSimulation()
        physicsEngine.isPaused = true  // Assumes isPaused var in PhysicsEngine
    }
    
    public func resumeSimulation() async {
        physicsEngine.isPaused = false
        await startSimulation()
    }
    
    // New: Added save method to fix the error in MenuView
    public func save() async {
        do {
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            print("Failed to save graph: \(error)")
        }
    }
    
    private func buildRoots() -> [any NodeProtocol] {
        var incoming = Set<NodeID>()
        for edge in edges {
            incoming.insert(edge.to)
        }
        return nodes.filter { !incoming.contains($0.id) }.map { $0.unwrapped }
    }
    // Visibility methods

    private func dfsVisible(node: any NodeProtocol, adjacency: [NodeID: [NodeID]], visited: inout Set<NodeID>, visible: inout [any NodeProtocol]) {
        visited.insert(node.id)
        visible.append(node)  // Always append (even if collapsed)
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
        edges.contains(where: { $0.from == id1 && $0.to == id2 }) &&  // Parenthesized
        edges.contains(where: { $0.from == id2 && $0.to == id1 })     // Parenthesized
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
    
}

@available(iOS 13.0, watchOS 6.0, *)
extension GraphModel {
    
    public func graphDescription(selectedID: NodeID?, selectedEdgeID: UUID?) -> String {
        let edgeCount = edges.count
        let edgeWord = edgeCount == 1 ? "edge" : "edges"  // New: Handle plural
        var desc = "Graph with \(nodes.count) nodes and \(edgeCount) directed \(edgeWord)."
        if let selectedEdgeID = selectedEdgeID, let selectedEdge = edges.first(where: { $0.id == selectedEdgeID }),
           let fromNode = nodes.first(where: { $0.id == selectedEdge.from })?.unwrapped,
           let toNode = nodes.first(where: { $0.id == selectedEdge.to })?.unwrapped {
            desc += " Directed edge from node \(fromNode.label) to node \(toNode.label) selected."
        } else if let selectedID = selectedID, let selectedNode = nodes.first(where: { $0.id == selectedID })?.unwrapped {
            let outgoingLabels = edges
                .filter { $0.from == selectedID }
                .compactMap { edge in
                    let toID = edge.to
                    return nodes.first { $0.id == toID }?.unwrapped.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            let incomingLabels = edges
                .filter { $0.to == selectedID }
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
