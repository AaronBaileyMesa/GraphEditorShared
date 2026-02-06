//
//  GraphModel.swift
//  GraphEditorShared
//
//  Created by handcart on 10/3/25.
//  Updated 2025-11-18: Added proper caching for hiddenNodeIDs → fixes massive redraw spam
//

import os.log
import SwiftUI
import Combine
import Foundation

#if os(watchOS)
import WatchKit
#endif

// swiftlint:disable type_body_length
// Rationale: GraphModel is the core domain model managing graph state, simulation lifecycle,
// ephemeral nodes, and persistence. Already split into extensions; further splitting would harm cohesion.

@available(iOS 16.0, watchOS 6.0, *)
@MainActor public class GraphModel: ObservableObject {
    @Published public var currentGraphName: String = "default"
    @Published public var nodes: [AnyNode] = []
    @Published public var edges: [GraphEdge] = []
    @Published public var isSimulating: Bool = false
    @Published public var editingNodeID: NodeID?  // NEW: Signals node to edit; nil hides sheet
    @Published public var draggedNodeID: NodeID?  // NEW: Tracks currently dragged node to prevent physics on it
    @Published public var isStable: Bool = false
    @Published public var simulationError: Error?
    @Published public var mode: GraphMode = .network
    @Published public var hierarchyEdgeColor: Color = .blue
    @Published public var associationEdgeColor: Color = .white
    // In GraphModel.swift
    
    @Published public var ephemeralControlNodes: [ControlNode] = []          // only these
    @Published public var ephemeralControlEdges: [GraphEdge] = []            // spring edges to owner
    var isUpdatingEphemerals: Bool = false
    
    public var uiConfig: [NodeID: [ControlConfig]] = [:]
    public var globalUiConfig: [ControlConfig] = []
    @Published public var priorityEdges: [NodeID: [GraphEdge]] = [:]  // For future slot occupation by real edges
    public var isConfigMode: Bool = false
    @Published public var cancellables: Set<AnyCancellable> = []
    
    public var allNodes: [any NodeProtocol] {
        nodes + ephemeralControlNodes
    }
    
    public var allEdges: [GraphEdge] {
        edges + ephemeralControlEdges
    }
    
    public let changesPublisher = PassthroughSubject<Void, Never>()
    
    internal static let logger = Logger.forCategory("graphmodel-storage")  // Changed from private to internal
    
    var simulationTimer: Timer?
    var undoStack: [UndoGraphState] = []
    var redoStack: [UndoGraphState] = []
    public var maxUndo: Int = 10
    
    public var nextNodeLabel = 1
    
    public let storage: GraphStorage
    public var physicsEngine: PhysicsEngine
    
    // MARK: - Hidden Nodes Caching (fixes extreme performance regression)
    
    private var cachedHiddenNodeIDs: Set<NodeID> = []
    private var hiddenNodesVersion: UInt64 = 0           // Incremented on any relevant mutation
    private var lastValidatedVersion: UInt64 = 0         // Version at which cache was last confirmed valid
    private var lastNodeUpdateTime: Date = .distantPast
    private let minimumUpdateInterval: TimeInterval = 1.0 / 30.0   // 30 FPS max for SwiftUI
    
    /// Public read-only accessor – O(1) most of the time
    public var hiddenNodeIDs: Set<NodeID> {
        // Fast path – cache is valid
        if hiddenNodesVersion == lastValidatedVersion {
            return cachedHiddenNodeIDs
        }
        
        // Slow path – recompute
        let newHidden = computeHiddenNodeIDs()
        cachedHiddenNodeIDs = newHidden
        lastValidatedVersion = hiddenNodesVersion
        return newHidden
    }
    
    /// Call this whenever ToggleNode.isExpanded or hierarchy edges change
    public func invalidateHiddenNodesCache() {
        hiddenNodesVersion &+= 1
    }
    
    /// The actual expensive work – now private and only called when needed
    private func computeHiddenNodeIDs() -> Set<NodeID> {
        var hidden = Set<NodeID>()
        var toHide: [NodeID] = []
        
#if DEBUG
        print("=== Computing hiddenNodeIDs ===")
#endif
        
        for wrapper in nodes {
            guard let toggleNode = wrapper.unwrapped as? ToggleNode, !toggleNode.isExpanded else {
#if DEBUG
                if let toggle = wrapper.unwrapped as? ToggleNode {
                    print("ToggleNode.shouldHideChildren for label \(toggle.label) (ID: \(wrapper.id.uuidString.prefix(8))): isExpanded = true, result = false")
                }
#endif
                continue
            }
            
            let children = edges
                .filter { $0.from == wrapper.id && $0.type == .hierarchy }
                .map { $0.target }
            
#if DEBUG
            print("ToggleNode.shouldHideChildren for label \(toggleNode.label) (ID: \(wrapper.id.uuidString.prefix(8))): isExpanded = false, result = true")
            print("  Adding to toHide: \(children.map { $0.uuidString.prefix(8) })")
#endif
            
            toHide.append(contentsOf: children)
        }
        
        let adj = buildAdjacencyList(for: .hierarchy)
        
#if DEBUG
        print("Adjacency list:")
        for (from, tos) in adj.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            print("  \(from.uuidString.prefix(8)): \(tos.map { $0.uuidString.prefix(8) }.joined(separator: ", "))")
        }
#endif
        
        // Fixed transitive closure – always explore children of collapsed ToggleNodes
        while !toHide.isEmpty {
            let current = toHide.removeLast()
            guard hidden.insert(current).inserted else { continue }  // skip if already hidden
            
            // Add ALL hierarchy children – even if they were already processed in a previous collapse
            let grandchildren = adj[current] ?? []
            toHide.append(contentsOf: grandchildren)
            
#if DEBUG
            print("  Added grandchildren: \(grandchildren.map { $0.uuidString.prefix(8) })")
#endif
        }
        
#if DEBUG
        print("Final hiddenNodeIDs: \(hidden.sorted(by: { $0.uuidString < $1.uuidString }))")
#endif
        
        return hidden
    }
    
    // MARK: - Simulator
    
    lazy var simulator: GraphSimulator = {
        GraphSimulator(
            getNodes: { [weak self] in
                await MainActor.run {
                    self?.nodes.map { $0.unwrapped } ?? []
                }
            },
            setNodes: { [weak self] newNodes in
                await MainActor.run {
                    guard let self else { return }
                    let now = Date()
                    if now.timeIntervalSince(self.lastNodeUpdateTime) < self.minimumUpdateInterval {
                        return
                    }
                    self.lastNodeUpdateTime = now
                    var updated = newNodes
                    for (index, var node) in updated.enumerated() where self.hiddenNodeIDs.contains(node.id) {
                        node = node.with(position: node.position, velocity: .zero)
                        updated[index] = node
                    }
                    self.nodes = updated.map { AnyNode($0) }
                }
            },
            getEphemerals: { [weak self] in
                await MainActor.run {
                    self?.ephemeralControlNodes ?? []
                }
            },
            setEphemerals: { [weak self] (newEphemerals: [any NodeProtocol]) in  // Parens fix parsing + capture issues
                await MainActor.run {
                    guard let self else { return }
                    let now = Date()
                    if now.timeIntervalSince(self.lastNodeUpdateTime) < self.minimumUpdateInterval {
                        return
                    }
                    self.lastNodeUpdateTime = now
                    self.setEphemerals(newEphemerals)
                }
            },
            getEdges: { [weak self] in
                await MainActor.run { self?.visibleEdges ?? [] }
            },
            getVisibleNodes: { [weak self] in
                await MainActor.run { self?.visibleNodes ?? [] }
            },
            getVisibleEdges: { [weak self] in
                await MainActor.run { self?.visibleEdges ?? [] }
            },
            getDraggedNodeID: { [weak self] in
                await MainActor.run { self?.draggedNodeID }
            },
            physicsEngine: self.physicsEngine,
            onStable: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    // CRITICAL: Don't center nodes when ephemeral control nodes are present
                    // Centering would shift ALL nodes (including controls) by the centroid delta,
                    // breaking the 40pt distance constraint between owner and controls
                    if self.ephemeralControlNodes.isEmpty {
                        let centered = self.physicsEngine.centerNodes(
                            nodes: self.nodes.map { $0.unwrapped }
                        )
                        self.nodes = centered.map {
                            AnyNode($0.with(position: $0.position, velocity: .zero))
                        }
                    }
                    self.isStable = true
                    try? await Task.sleep(for: .seconds(0.5))
                    self.isStable = false
                    await self.stopSimulation()
                }
            },
            onPostStable: { [weak self] in
                Task { @MainActor in
                    self?.isSimulating = false
                    Self.logger.infoLog("Auto-paused simulation after inactivity")
                }
            } /*,
             getAllEdges: { self.allEdges },
             getHiddenNodeIDs: { self.hiddenNodeIDs },  // If private, add public getter or change visibility
             invalidateHiddenNodesCache: { self.invalidateHiddenNodesCache() },*/
        )
    }()
    
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    
    public init(storage: GraphStorage, physicsEngine: PhysicsEngine) {
        self.storage = storage
        self.physicsEngine = physicsEngine
        Self.logger.infoLog("GraphModel initialized with storage: \(type(of: storage))")
    }
    
    func buildAdjacencyList(for type: EdgeType) -> [NodeID: [NodeID]] {
        var adj: [NodeID: [NodeID]] = [:]
        for edge in edges where edge.type == type {
            adj[edge.from, default: []].append(edge.target)
        }
        return adj
    }
    
    // MARK: - Visible Nodes & Edges (now also cached indirectly via hiddenNodeIDs)
    // In GraphModel.swift (or wherever this extension lives)
    @MainActor
    func visibleNodesAndEdges() -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        let hidden = hiddenNodeIDs
        
        // Build the set of IDs that are actually visible (persistent nodes)
        var visibleNodeIDs = Set(nodes.lazy
            .filter { !hidden.contains($0.id) }
            .map { $0.id })
        
        var visibleNodes: [any NodeProtocol] = []
        visibleNodes.reserveCapacity(nodes.count + ephemeralControlNodes.count)
        
        for node in nodes where visibleNodeIDs.contains(node.id) {
            visibleNodes.append(node.unwrapped)
        }
        
        // NEW: Append ephemerals (always visible)
        visibleNodes.append(contentsOf: ephemeralControlNodes)
        
        // NEW: Add ephemeral IDs to visibleNodeIDs for edge filtering
        visibleNodeIDs.formUnion(ephemeralControlNodes.map { $0.id })
        
        // Visible persistent hierarchy edges
        var visibleEdges = edges.filter { edge in
            edge.type == .hierarchy &&
            visibleNodeIDs.contains(edge.from) &&
            visibleNodeIDs.contains(edge.target)
        }
        
        // NEW: Append ephemeral spring edges if both ends visible
        visibleEdges.append(contentsOf: ephemeralControlEdges.filter { edge in
            visibleNodeIDs.contains(edge.from) &&
            visibleNodeIDs.contains(edge.target)
        })
        
        return (visibleNodes, visibleEdges)
    }
    
    // MARK: - Merge physics results back into full model
    @MainActor
    private func mergeVisibleNodesIntoFullModel(updatedVisibleNodes: [any NodeProtocol]) {
        var nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        
        for updatedNode in updatedVisibleNodes {
            nodeMap[updatedNode.id] = AnyNode(updatedNode)
        }
        
        // Freeze hidden nodes so they don’t drift
        for hiddenID in hiddenNodeIDs {
            if let wrapper = nodeMap[hiddenID] {
                let current = wrapper.unwrapped
                let frozen = current.with(position: current.position, velocity: .zero)
                nodeMap[hiddenID] = AnyNode(frozen)
            }
        }
        
        self.nodes = nodeMap.values.sorted { $0.id.uuidString < $1.id.uuidString }
        objectWillChange.send()
    }
    
    // MARK: - Load-time velocity reset (fixes 500-iteration launch bug)
    @MainActor
    public func zeroAllVelocities() {
        guard !nodes.isEmpty else { return }
        
        nodes = nodes.map { wrapper in
            let node = wrapper.unwrapped
            let frozen = node.with(position: node.position, velocity: .zero)
            return AnyNode(frozen)
        }
        
        // Important: notify SwiftUI + simulator that nodes changed
        objectWillChange.send()
        invalidateHiddenNodesCache()
    }
    
    // MARK: - Control Node Cluster (visual parenting, no physics springs)
    @MainActor
    public func updateControlNodes(for selectedNodeID: NodeID?) {
        ephemeralControlNodes.removeAll()
        ephemeralControlEdges.removeAll()
        
        guard let selectedID = selectedNodeID,
              let ownerNode = nodes.first(where: { $0.id == selectedID })?.unwrapped
        else { return }

        _ = ownerNode is ToggleNode

        let kinds: [ControlKind] = [.addChild, .addEdge, .edit]
        
        let clusterRadius = ownerNode.radius * 2.2
        
        for (index, kind) in kinds.enumerated() {
            let angle = CGFloat(index) * .pi * 2 / CGFloat(kinds.count) - .pi / 2
            let offset = CGPoint(x: cos(angle), y: sin(angle)) * clusterRadius
            
            let control = ControlNode(
                position: ownerNode.position + offset,
                ownerID: selectedID,
                kind: kind
            )
            
            ephemeralControlNodes.append(control)
            
            // NEW: Add spring edge from owner to control
            let springEdge = GraphEdge(
                from: selectedID,
                target: control.id,
                type: .spring  // Assuming .spring is defined in EdgeType enum; add if missing
            )
            ephemeralControlEdges.append(springEdge)
        }
        
        // NEW: Invalidate caches and notify after changes
        invalidateHiddenNodesCache()
        objectWillChange.send()
        Self.logger.debug("Added \(self.ephemeralControlNodes.count) controls for owner \(selectedID.uuidString) – initial redraw triggered")
        
        // NEW: Trigger brief initial simulation for settling (e.g., 10 steps)
        Task {  // Change to non-detached (runs on current actor, safer for MainActor model)
            for _ in 0..<10 {  // Tunable: More steps for smoother settling
                _ = await self.simulator.performSimulationStep(baseInterval: 1.0 / 60.0, nodeCount: self.allNodes.count)
                try? await Task.sleep(nanoseconds: 16_666_667)  // ~60 FPS delay
                await MainActor.run {  // NEW: Publish per step for incremental redraws
                    self.objectWillChange.send()
                    Self.logger.debug("Control simulation step complete – positions updated")
                }
            }
            
            Self.logger.debug("Completed brief simulation for controls – \(self.ephemeralControlNodes.count) nodes settled")
        }
    }
    
    private func setEphemerals(_ newEphemerals: [any NodeProtocol]) {
        ephemeralControlNodes = newEphemerals.compactMap { $0 as? ControlNode }
    }
}

extension GraphModel {
    public var visibleNodes: [any NodeProtocol] {
        visibleNodesAndEdges().nodes + ephemeralControlNodes
    }
    public var visibleEdges: [GraphEdge] {
        visibleNodesAndEdges().edges + ephemeralControlEdges
    }
}
// swiftlint:enable type_body_length
