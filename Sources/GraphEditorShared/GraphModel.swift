// Sources/GraphEditorShared/GraphModel.swift

import os.log
import SwiftUI
import Combine
import Foundation

#if os(watchOS)
import WatchKit
#endif

private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "storage")

public class GraphModel: ObservableObject {
    @Published public var nodes: [any NodeProtocol] = []
    @Published public var edges: [GraphEdge] = []
    
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    internal var nextNodeLabel = 1  // Internal for testability; auto-increments node labels
    
    private let storage: GraphStorage
    public let physicsEngine: PhysicsEngine  // Changed to public
    
    private lazy var simulator: GraphSimulator = {
        GraphSimulator(
            getNodes: { [weak self] in (self?.nodes as? [Node]) ?? [] },  // Cast to [Node] for simulator
            setNodes: { [weak self] nodes in self?.nodes = nodes as [any NodeProtocol] },  // Cast back to existential
            getEdges: { [weak self] in self?.edges ?? [] },
            physicsEngine: self.physicsEngine
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
    
    // Initializes the graph model, loading from persistence if available.
    public init(storage: GraphStorage = PersistenceManager(), physicsEngine: PhysicsEngine) {
        self.storage = storage
        self.physicsEngine = physicsEngine
        
        var tempNodes: [any NodeProtocol] = []
        var tempEdges: [GraphEdge] = []
        var tempNextLabel = 1
        
        do {
            let loaded = try storage.load()
            tempNodes = loaded.nodes
            tempEdges = loaded.edges
            tempNextLabel = (tempNodes.map { $0.label }.max() ?? 0) + 1
        } catch {
            logger.error("Load failed: \(error.localizedDescription)")
            // Proceed with defaults below
        }
        
        if tempNodes.isEmpty && tempEdges.isEmpty {
            let defaultNodes: [Node] = [
                Node(label: tempNextLabel, position: CGPoint(x: 100, y: 100)),
                Node(label: tempNextLabel + 1, position: CGPoint(x: 200, y: 200)),
                Node(label: tempNextLabel + 2, position: CGPoint(x: 150, y: 300))
            ]
            tempNodes = defaultNodes
            tempNextLabel += 3
            tempEdges = [
                GraphEdge(from: defaultNodes[0].id, to: defaultNodes[1].id),
                GraphEdge(from: defaultNodes[1].id, to: defaultNodes[2].id),
                GraphEdge(from: defaultNodes[2].id, to: defaultNodes[0].id)
            ]
            do {
                try storage.save(nodes: defaultNodes, edges: tempEdges)
            } catch {
                logger.error("Save defaults failed: \(error.localizedDescription)")
            }
        } else {
            // Update nextLabel based on loaded nodes
            tempNextLabel = (tempNodes.map { $0.label }.max() ?? 0) + 1
            // NO save here; loaded data doesn't need immediate save
        }
        
        self.nodes = tempNodes
        self.edges = tempEdges
        self.nextNodeLabel = tempNextLabel
    }

    // Test-only initializer
    #if DEBUG
    public init(storage: GraphStorage = PersistenceManager(), physicsEngine: PhysicsEngine, nextNodeLabel: Int) {
        self.storage = storage
        self.physicsEngine = physicsEngine
        
        var tempNodes: [any NodeProtocol] = []
        var tempEdges: [GraphEdge] = []
        var tempNextLabel = nextNodeLabel
        
        do {
            let loaded = try storage.load()
            tempNodes = loaded.nodes
            tempEdges = loaded.edges
            tempNextLabel = (tempNodes.map { $0.label }.max() ?? 0) + 1
        } catch {
            logger.error("Load failed: \(error.localizedDescription)")
        }
        
        if tempNodes.isEmpty && tempEdges.isEmpty {
            let defaultNodes: [Node] = [
                Node(label: tempNextLabel, position: CGPoint(x: 100, y: 100)),
                Node(label: tempNextLabel + 1, position: CGPoint(x: 200, y: 200)),
                Node(label: tempNextLabel + 2, position: CGPoint(x: 150, y: 300))
            ]
            tempNodes = defaultNodes
            tempNextLabel += 3
            tempEdges = [
                GraphEdge(from: defaultNodes[0].id, to: defaultNodes[1].id),
                GraphEdge(from: defaultNodes[1].id, to: defaultNodes[2].id),
                GraphEdge(from: defaultNodes[2].id, to: defaultNodes[0].id)
            ]
            do {
                try storage.save(nodes: defaultNodes, edges: tempEdges)
            } catch {
                logger.error("Failed to save default graph: \(error.localizedDescription)")
            }
        } else {
            tempNextLabel = (tempNodes.map { $0.label }.max() ?? 0) + 1
        }
        
        self.nodes = tempNodes
        self.edges = tempEdges
        self.nextNodeLabel = tempNextLabel
    }
    #endif
    
    // Creates a snapshot of the current state for undo/redo and saves.
    public func snapshot() {
        let state = GraphState(nodes: nodes as! [Node], edges: edges)  // Cast for GraphState (assumes all are Node)
        undoStack.append(state)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        do {
            try storage.save(nodes: nodes as! [Node], edges: edges)  // Cast for save
        } catch {
            logger.error("Failed to save snapshot: \(error.localizedDescription)")
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
        let current = GraphState(nodes: nodes as! [Node], edges: edges)
        redoStack.append(current)
        let previous = undoStack.removeLast()
        nodes = previous.nodes as [any NodeProtocol]  // Conversion from [Node]
        edges = previous.edges
        self.physicsEngine.resetSimulation()  // Ready for new simulation
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
        do {
            try storage.save(nodes: nodes as! [Node], edges: edges)
        } catch {
            logger.error("Failed to save after undo: \(error.localizedDescription)")
        }
    }
    
    public func redo() {
        guard !redoStack.isEmpty else {
            #if os(watchOS)
            WKInterfaceDevice.current().play(.failure)
            #endif
            return
        }
        let current = GraphState(nodes: nodes as! [Node], edges: edges)
        undoStack.append(current)
        let next = redoStack.removeLast()
        nodes = next.nodes as [any NodeProtocol]
        edges = next.edges
        self.physicsEngine.resetSimulation()  // Ready for new simulation
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
        do {
            try storage.save(nodes: nodes as! [Node], edges: edges)
        } catch {
            logger.error("Failed to save after redo: \(error.localizedDescription)")
        }
    }
    
    public func saveGraph() {
        do {
            try storage.save(nodes: nodes as! [Node], edges: edges)
        } catch {
            logger.error("Failed to save graph: \(error.localizedDescription)")
        }
    }
    
    public func deleteNode(withID id: NodeID) {
        snapshot()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
        self.physicsEngine.resetSimulation()
    }
    
    public func deleteEdge(withID id: NodeID) {
        snapshot()
        edges.removeAll { $0.id == id }
        self.physicsEngine.resetSimulation()
    }
    
    public func addNode(at position: CGPoint) {
        nodes.append(Node(label: nextNodeLabel, position: position, radius: 10.0))  // Explicit radius; vary later if needed
        nextNodeLabel += 1
        if nodes.count >= 100 {
            // Trigger alert via view (e.g., publish @Published var showNodeLimitAlert = true)
            return
        }
        self.physicsEngine.resetSimulation()
    }
    
    public func startSimulation() {
        simulator.startSimulation(onUpdate: { [weak self] in
            self?.objectWillChange.send()
        })
    }
    
    public func stopSimulation() {
        simulator.stopSimulation()
    }
    
    public func boundingBox() -> CGRect {
        self.physicsEngine.boundingBox(nodes: nodes as! [Node])  // Cast for physicsEngine
    }
    
    // Visibility methods
    public func visibleNodes() -> [any NodeProtocol] {
        var visible = [any NodeProtocol]()
        var visited = Set<NodeID>()
        let adjacency = buildAdjacencyList()
        for node in nodes {
            if node.isVisible && !visited.contains(node.id) {
                dfsVisible(node: node, adjacency: adjacency, visited: &visited, visible: &visible)
            }
        }
        return visible
    }

    private func dfsVisible(node: any NodeProtocol, adjacency: [NodeID: [NodeID]], visited: inout Set<NodeID>, visible: inout [any NodeProtocol]) {
        visited.insert(node.id)
        visible.append(node)
        if let toggle = node as? ToggleNode, !toggle.isExpanded { return }  // Skip children if collapsed (cast to check type)
        if let children = adjacency[node.id] {
            for childID in children {
                if !visited.contains(childID), let child = nodes.first(where: { $0.id == childID }), child.isVisible {
                    dfsVisible(node: child, adjacency: adjacency, visited: &visited, visible: &visible)
                }
            }
        }
    }

    public func visibleEdges() -> [GraphEdge] {
        let visibleIDs = Set(visibleNodes().map { $0.id })
        return edges.filter { visibleIDs.contains($0.from) && visibleIDs.contains($0.to) }
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
}

extension GraphModel {
    public func graphDescription(selectedID: NodeID?) -> String {
        var desc = "Graph with \(nodes.count) nodes and \(edges.count) directed edges."
        if let selectedID, let selectedNode = nodes.first(where: { $0.id == selectedID }) {
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
            desc += " No node selected."
        }
        return desc
    }
}
