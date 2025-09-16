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
    @Published public var nodes: [AnyNode] = []
    @Published public var edges: [GraphEdge] = []
    @Published public var isSimulating: Bool = false
    @Published public var isStable: Bool = false
    @Published public var simulationError: Error?

    private var simulationTimer: Timer?
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    public var nextNodeLabel = 1

    private let storage: GraphStorage
    public var physicsEngine: PhysicsEngine

    public var hiddenNodeIDs: Set<NodeID> {
        var hidden = Set<NodeID>()
        var toHide: [NodeID] = []

        for node in nodes where node.unwrapped.shouldHideChildren() {
            let children = edges.filter { $0.from == node.id && $0.type == .hierarchy }.map { $0.target }
            toHide.append(contentsOf: children)
        }

        let adj = buildAdjacencyList(for: .hierarchy)
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
            getNodes: { [weak self] in self?.nodes.map { $0.unwrapped } ?? [] },
            setNodes: { [weak self] newNodes in
                self?.nodes = newNodes.map { AnyNode($0) }
            },
            getEdges: { [weak self] in self?.edges ?? [] },
            getVisibleNodes: { [weak self] in self?.visibleNodes() ?? [] },
            getVisibleEdges: { [weak self] in self?.visibleEdges() ?? [] },
            physicsEngine: self.physicsEngine,
            onStable: { [weak self] in
                guard let self = self, !self.isStable else { return }
                let velocities = self.nodes.map { hypot($0.velocity.x, $0.velocity.y) }
                if velocities.allSatisfy({ $0 < 0.001 }) {
                    print("Simulation stable: Centering nodes")
                    let centeredNodes = self.physicsEngine.centerNodes(nodes: self.nodes.map { $0.unwrapped })
                    self.nodes = centeredNodes.map { AnyNode($0.with(position: $0.position, velocity: .zero)) }
                    self.isStable = true
                    Task {
                        await self.stopSimulation()
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        self.isStable = false
                    }
                    self.objectWillChange.send()
                }
            }
        )
    }()

    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    public var canRedo: Bool {
        !redoStack.isEmpty
    }

    public init(storage: GraphStorage, physicsEngine: PhysicsEngine) {
        self.storage = storage
        self.physicsEngine = physicsEngine
    }
}

@available(iOS 13.0, watchOS 6.0, *)
public struct GraphViewState {
    public var offset: CGPoint
    public var zoomScale: CGFloat
    public var selectedNodeID: UUID?
    public var selectedEdgeID: UUID?
}

@available(iOS 13.0, watchOS 6.0, *)
extension GraphModel {
    private func loadFromStorage() async throws {
        let (loadedNodes, loadedEdges) = try await storage.load()
        self.nodes = loadedNodes.map { AnyNode($0) }
        self.edges = loadedEdges
        self.nextNodeLabel = (nodes.map { $0.unwrapped.label }.max() ?? 0) + 1
    }

    public func load() async {
        do {
            try await loadFromStorage()
            syncCollapsedPositions()
        } catch {
            print("Failed to load graph: \(error)")
        }
    }

    public func save() async {
        do {
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            print("Failed to save graph: \(error)")
        }
    }

    private func syncCollapsedPositions() {
        for parentIndex in 0..<nodes.count {
            if let toggle = nodes[parentIndex].unwrapped as? ToggleNode, !toggle.isExpanded {
                let children = edges.filter { $0.from == nodes[parentIndex].id && $0.type == .hierarchy }.map { $0.target }
                for (index, childID) in children.enumerated() {
                    guard let childIndex = nodes.firstIndex(where: { $0.id == childID }) else { continue }
                    var child = nodes[childIndex]
                    let angle = CGFloat(index) * (2 * .pi / CGFloat(children.count))
                    let jitterX = cos(angle) * 5.0
                    let jitterY = sin(angle) * 5.0
                    child.position = nodes[parentIndex].position + CGPoint(x: jitterX, y: jitterY)
                    child.velocity = .zero
                    nodes[childIndex] = child
                }
            }
        }
        objectWillChange.send()
    }

    public func clearGraph() async {
        nodes = []
        edges = []
        nextNodeLabel = 1
        try? await storage.clear()
        objectWillChange.send()
    }
}

@available(iOS 13.0, watchOS 6.0, *)
extension GraphModel {
    public func visibleNodes() -> [any NodeProtocol] {
        let hidden = hiddenNodeIDs
        return nodes.filter { !hidden.contains($0.id) }.map { $0.unwrapped }
    }

    public func visibleEdges() -> [GraphEdge] {
        let hidden = hiddenNodeIDs
        return edges.filter { !hidden.contains($0.from) && !hidden.contains($0.target) }
    }

    public func boundingBox() -> CGRect {
        self.physicsEngine.boundingBox(nodes: nodes.map { $0.unwrapped })
    }

    public func centerGraph() {
        let centered = physicsEngine.centerNodes(nodes: nodes.map { $0.unwrapped })
        nodes = centered.map { AnyNode($0) }
        objectWillChange.send()
    }

    public func expandAllRoots() async {
        for var root in buildRoots() {
            root.isExpanded = true
            if let index = nodes.firstIndex(where: { $0.id == root.id }) {
                nodes[index] = AnyNode(root)
            }
        }
        objectWillChange.send()
    }

    private func buildRoots() -> [any NodeProtocol] {
        var incoming = Set<NodeID>()
        for edge in edges {
            incoming.insert(edge.target)
        }
        return nodes.filter { !incoming.contains($0.id) }.map { $0.unwrapped }
    }
}

@available(iOS 13.0, watchOS 6.0, *)
extension GraphModel {
    public func resizeSimulationBounds(for nodeCount: Int) async {
        let newSize = max(300.0, sqrt(Double(nodeCount)) * 100.0)
        self.physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: newSize, height: newSize))
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

    public func startSimulation() async {
        isStable = false
        simulationError = nil
        isSimulating = true
        await simulator.startSimulation()
        isSimulating = false
    }

    public func stopSimulation() async {
        await simulator.stopSimulation()
    }

    public func pauseSimulation() async {
        await stopSimulation()
        physicsEngine.isPaused = true
    }

    public func resumeSimulation() async {
        physicsEngine.isPaused = false
        await startSimulation()
    }
}

@available(iOS 13.0, watchOS 6.0, *)
extension GraphModel {
    public func wouldCreateCycle(withNewEdgeFrom from: NodeID, target: NodeID, type: EdgeType) -> Bool {
        guard type == .hierarchy else { return false }
        var tempEdges = edges.filter { $0.type == .hierarchy }
        tempEdges.append(GraphEdge(from: from, to: target, type: type))
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
        edges.append(GraphEdge(from: from, to: target, type: type))
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
        await addEdge(from: parentID, target: newNode.id, type: .hierarchy)
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

@available(iOS 13.0, watchOS 6.0, *)
extension GraphModel {
    public func snapshot() async {
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

    public func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) throws {
        // Implement saving logic here
    }

    public func loadViewState() throws -> GraphViewState? {
        // Implement loading logic here
        return nil
    }
}

@available(iOS 13.0, watchOS 6.0, *)
extension GraphModel {
    private func buildAdjacencyList(for edgeType: EdgeType? = nil) -> [NodeID: [NodeID]] {
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

        let children = edges.filter { $0.from == nodeID && $0.type == .hierarchy }.map { $0.target }

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
}

@available(iOS 13.0, watchOS 6.0, *)
extension GraphModel {
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
                    let toID = edge.target
                    return nodes.first { $0.id == toID }?.unwrapped.label
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
