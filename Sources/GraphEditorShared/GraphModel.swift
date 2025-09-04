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
        }

        static func defaultGraph() -> ([AnyNode], [GraphEdge], Int) {
            // Based on tests (3 nodes, 3 edges); adjust as needed
            let node1 = AnyNode(Node(label: 1, position: .zero))
            let node2 = AnyNode(Node(label: 2, position: CGPoint(x: 100, y: 0)))
            let node3 = AnyNode(Node(label: 3, position: CGPoint(x: 50, y: 100)))
            let edges = [
                GraphEdge(from: node1.id, to: node2.id),
                GraphEdge(from: node2.id, to: node3.id),
                GraphEdge(from: node3.id, to: node1.id)
            ]
            return ([node1, node2, node3], edges, 4)  // Next label after 3
        }

    public func clearGraph() async {
        await snapshot()
        nodes = []
        edges = []
        nextNodeLabel = 1  // Explicit reset
        physicsEngine.resetSimulation()
        await startSimulation()
        try? await storage.clear()
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
    public func snapshot() async {
        let state = GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges)  // Unwrap for state (keep storage light)
        undoStack.append(state)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        do {
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            os_log("Failed to save snapshot: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    // Undoes the last action if possible, with haptic feedback.
    public func undo() async {
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
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            os_log("Failed to save after undo: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func redo() async {
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
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
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
    
    public func addNode(at position: CGPoint) async {
        await snapshot()
        let newNode = Node(label: nextNodeLabel, position: position, content: nil)
        nextNodeLabel += 1
        nodes.append(AnyNode(newNode))
        physicsEngine.resetSimulation()
        await startSimulation()
        do {
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            os_log("Save failed: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func addEdge(from fromID: NodeID, to toID: NodeID) async {
        await snapshot()
        if edges.contains(where: { $0.from == fromID && $0.to == toID }) { return }  
        let newEdge = GraphEdge(from: fromID, to: toID)
        edges.append(newEdge)
        physicsEngine.resetSimulation()
        await startSimulation()
        do {
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            os_log("Save failed: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    // Add this public save method (if truncated/missing; place after resumeSimulation)
    public func save() async {
        do {
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            os_log("Failed to save graph: %{public}s", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    public func addToggleNode(at position: CGPoint) async {
        await snapshot()
        let newNode = AnyNode(ToggleNode(label: nextNodeLabel, position: position))
        nodes.append(newNode)
        nextNodeLabel += 1
        physicsEngine.resetSimulation()
        await startSimulation()
    }
            
    public func updateNodeContent(withID id: NodeID, newContent: NodeContent?) async {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        var updatedNode = nodes[index]
        updatedNode.content = newContent  // Assumes AnyNode supports mutable content
        nodes[index] = updatedNode
        await snapshot()  // Save undo state
        physicsEngine.temporaryDampingBoost()  // Optional: Boost for quick settling (from prior fixes)
        await startSimulation()  // Restart sim to reflect changes visually
    }
    
    @MainActor
    public func updateNode(withID id: NodeID, newPosition: CGPoint? = nil, newContent: NodeContent? = nil) async {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else {
            print("Warning: No node found for update with ID \(id.uuidString)")  // Debug for usability
            return
        }
        let original = nodes[index]  // AnyNode
        var updatedUnwrapped = original.unwrapped  // Unwrap to any NodeProtocol for updates
        
        if let newPosition = newPosition {
            updatedUnwrapped = updatedUnwrapped.with(position: newPosition, velocity: .zero)  // Reset velocity to avoid drifts
        } else if let newContent = newContent {
            // Option 1: Direct mutation (if your existentials support it)
            // updatedUnwrapped.content = newContent
            
            // Option 2: Immutable pattern (add to NodeProtocol if missing)
            updatedUnwrapped = updatedUnwrapped.with(position: updatedUnwrapped.position, velocity: updatedUnwrapped.velocity, content: newContent)
        } else {
            // Handle tap/toggle (e.g., for ToggleNode)
            updatedUnwrapped = updatedUnwrapped.handlingTap()  // Toggles isExpanded if applicable; returns any NodeProtocol
        }
        
        nodes[index] = AnyNode(updatedUnwrapped)  // Re-wrap as AnyNode for assignment (fixes type error)
        await snapshot()  // Save undo state
        
        physicsEngine.temporaryDampingBoost()  // NEW: Boost damping for quick settling post-change
        
        await startSimulation()  // Restart sim with boosted damping active
    }
    
    public func deleteNode(withID id: NodeID) async {
        await snapshot()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
        physicsEngine.resetSimulation()
        await startSimulation()
        await save()
    }
      public func deleteEdge(withID id: UUID) async {
        await snapshot()
        edges.removeAll { $0.id == id }
        await startSimulation()
        await save()
    }
    
    public func addChild(to parentID: NodeID, isToggle: Bool = false) async {
        await snapshot()
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
        await startSimulation()
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
       
    // Added: Public wrappers for view state (delegate to storage)
    public func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) throws {
        try storage.saveViewState(offset: offset, zoomScale: zoomScale, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
    }
    
    public func loadViewState() throws -> (offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?)? {
        try storage.loadViewState()
    }
    
    public func expandAllRoots() async {
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
            await startSimulation()
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
