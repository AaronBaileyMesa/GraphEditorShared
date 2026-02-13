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
    @Published public var layoutMode: LayoutMode = .network
    @Published public var hierarchyEdgeColor: Color = .blue
    @Published public var associationEdgeColor: Color = .white
    // In GraphModel.swift
    
    @Published public var ephemeralControlNodes: [ControlNode] = []          // only these
    @Published public var ephemeralControlEdges: [GraphEdge] = []            // spring edges to owner
    var isUpdatingEphemerals: Bool = false
    
    public var uiConfig: [NodeID: [ControlConfig]] = [:]
    public var globalUiConfig: [ControlConfig] = []
    @Published public var priorityEdges: [NodeID: [GraphEdge]] = [:]  // For future slot occupation by real edges

    // PERFORMANCE: Cache person-to-table lookups to avoid O(N*M) searches during rendering
    internal var personToTableCache: [NodeID: NodeID] = [:]  // PersonID -> TableID
    public var isConfigMode: Bool = false
    
    // MARK: - Directional Layout Segments
    @Published public var segmentConfigs: [NodeID: SegmentConfig] = [:]  // Root node ID -> segment config
    @Published public var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Table Seating
    @Published public var tableSeatingsByMeal: [NodeID: TableSeating] = [:]  // Meal ID -> seating arrangement
    
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
    public var maxUndo: Int = 30  // Increased from 10 for better UX
    
    // Bulk operation mode - when true, defer simulation until endBulkOperation()
    private var isBulkOperationMode: Bool = false
    private var bulkOperationNeedsSimulation: Bool = false
    
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
    
    /// Call this whenever a collapsible node's isExpanded state or hierarchy edges change
    public func invalidateHiddenNodesCache() {
        hiddenNodesVersion &+= 1
    }
    
    /// The actual expensive work – now private and only called when needed
    private func computeHiddenNodeIDs() -> Set<NodeID> {
        var hidden = Set<NodeID>()
        var toHide: [NodeID] = []

#if DEBUG
        if LogManager.verboseSimulationLogging {
            print("=== Computing hiddenNodeIDs ===")
        }
#endif

        for wrapper in nodes {
            let node = wrapper.unwrapped
            // Check if node is collapsible and collapsed (should hide children)
            guard let concreteNode = node as? Node, concreteNode.isCollapsible, !concreteNode.isExpanded else {
#if DEBUG
                if LogManager.verboseSimulationLogging, let debugNode = node as? Node, debugNode.isCollapsible {
                    print("Collapsible node label \(debugNode.label) (ID: \(wrapper.id.uuidString.prefix(8))): isExpanded = true, result = false")
                }
#endif
                continue
            }

            let children = edges
                .filter { $0.from == wrapper.id && $0.type == .hierarchy }
                .map { $0.target }

#if DEBUG
            if LogManager.verboseSimulationLogging {
                print("Collapsible node label \(concreteNode.label) (ID: \(wrapper.id.uuidString.prefix(8))): isExpanded = false, result = true")
                print("  Adding to toHide: \(children.map { $0.uuidString.prefix(8) })")
            }
#endif

            toHide.append(contentsOf: children)
        }

        let adj = buildAdjacencyList(for: .hierarchy)

#if DEBUG
        if LogManager.verboseSimulationLogging {
            print("Adjacency list:")
            for (from, tos) in adj.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
                print("  \(from.uuidString.prefix(8)): \(tos.map { $0.uuidString.prefix(8) }.joined(separator: ", "))")
            }
        }
#endif

        // Fixed transitive closure – always explore children of collapsed collapsible nodes
        while !toHide.isEmpty {
            let current = toHide.removeLast()
            guard hidden.insert(current).inserted else { continue }  // skip if already hidden

            // Add ALL hierarchy children – even if they were already processed in a previous collapse
            let grandchildren = adj[current] ?? []
            toHide.append(contentsOf: grandchildren)

#if DEBUG
            if LogManager.verboseSimulationLogging {
                print("  Added grandchildren: \(grandchildren.map { $0.uuidString.prefix(8) })")
            }
#endif
        }

#if DEBUG
        if LogManager.verboseSimulationLogging {
            print("Final hiddenNodeIDs: \(hidden.sorted(by: { $0.uuidString < $1.uuidString }))")
        }
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
            getSegmentConfigs: { [weak self] in
                await MainActor.run { self?.segmentConfigs ?? [:] }
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
    
    public func setLayoutMode(_ mode: LayoutMode) {
        layoutMode = mode
        physicsEngine.updateLayoutMode(mode)
        Self.logger.infoLog("Layout mode updated to: \(mode)")
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
        // Filter out ChoiceNodes - they're only shown in DecisionNodeMenuView
        var visibleNodeIDs = Set(nodes.lazy
            .filter { !hidden.contains($0.id) }
            .filter { !($0.unwrapped is ChoiceNode) }  // Hide choice nodes from visual graph
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
        
        // Visible persistent edges (hierarchy and precedes)
        var visibleEdges = edges.filter { edge in
            (edge.type == .hierarchy || edge.type == .precedes) &&
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
    
    // MARK: - Bulk Operations
    
    /// Begin bulk operation mode - defers simulation until endBulkOperation()
    /// Use this when performing many operations in sequence to improve performance
    @MainActor
    public func beginBulkOperation() async {
        isBulkOperationMode = true
        bulkOperationNeedsSimulation = false
        await stopSimulation()
        Self.logger.debug("Bulk operation mode: started")
    }
    
    /// End bulk operation mode and resume simulation if needed
    @MainActor
    public func endBulkOperation() async {
        isBulkOperationMode = false
        if bulkOperationNeedsSimulation {
            await startSimulation()
            Self.logger.debug("Bulk operation mode: ended, simulation resumed")
        } else {
            Self.logger.debug("Bulk operation mode: ended, no simulation needed")
        }
        bulkOperationNeedsSimulation = false
    }
    
    /// Check if we should defer simulation (internal helper)
    @MainActor
    internal func shouldDeferSimulation() -> Bool {
        return isBulkOperationMode
    }
    
    /// Mark that simulation should be resumed after bulk operation
    @MainActor
    internal func markSimulationNeeded() {
        if isBulkOperationMode {
            bulkOperationNeedsSimulation = true
        }
    }
    
    // MARK: - Directional Layout Segments
    
    /// Get segment configuration for a node (looks up by finding root node)
    @MainActor
    public func getSegmentConfig(for nodeID: NodeID) -> SegmentConfig? {
        // First check if this node itself is a segment root
        if let config = segmentConfigs[nodeID] {
            return config
        }
        
        // Otherwise, traverse up hierarchy to find segment root
        guard let rootID = findSegmentRoot(for: nodeID) else {
            return nil
        }
        
        return segmentConfigs[rootID]
    }
    
    /// Find the root node of the segment this node belongs to
    @MainActor
    public func findSegmentRoot(for nodeID: NodeID) -> NodeID? {
        // Build parent map from hierarchy edges
        var parentMap: [NodeID: NodeID] = [:]
        for edge in edges where edge.type == .hierarchy {
            parentMap[edge.target] = edge.from
        }
        
        // Traverse up to find root (node with no parent or node that has a segment config)
        var currentID = nodeID
        var visited = Set<NodeID>()
        
        while let parentID = parentMap[currentID] {
            // Avoid infinite loops
            guard !visited.contains(currentID) else { break }
            visited.insert(currentID)
            
            // If parent has a segment config, that's our root
            if segmentConfigs[parentID] != nil {
                return parentID
            }
            
            currentID = parentID
        }
        
        // If we reached a root and it has a config, return it
        if segmentConfigs[currentID] != nil {
            return currentID
        }
        
        return nil
    }
    
    /// Set or update segment configuration for a root node
    @MainActor
    public func setSegmentConfig(
        rootNodeID: NodeID,
        direction: LayoutDirection,
        strength: CGFloat = 0.7,
        nodeSpacing: CGFloat = 60.0
    ) {
        let config = SegmentConfig(
            rootNodeID: rootNodeID,
            direction: direction,
            strength: strength,
            nodeSpacing: nodeSpacing
        )
        segmentConfigs[rootNodeID] = config
        changesPublisher.send()
        
        // Trigger layout update
        Task { @MainActor in
            await startSimulation()
        }
    }
    
    /// Remove segment configuration
    @MainActor
    public func removeSegmentConfig(rootNodeID: NodeID) {
        segmentConfigs.removeValue(forKey: rootNodeID)
        changesPublisher.send()
    }
    
    /// Get all nodes belonging to a segment (root + descendants via hierarchy edges)
    @MainActor
    public func getSegmentNodes(rootNodeID: NodeID) -> [any NodeProtocol] {
        var segmentNodes: [any NodeProtocol] = []
        
        // Find root node
        guard let rootNode = nodes.first(where: { $0.id == rootNodeID }) else {
            return []
        }
        
        segmentNodes.append(rootNode.unwrapped)
        
        // Build adjacency map for hierarchy edges
        var childrenMap: [NodeID: [NodeID]] = [:]
        for edge in edges where edge.type == .hierarchy {
            childrenMap[edge.from, default: []].append(edge.target)
        }
        
        // BFS to collect all descendants
        var queue = [rootNodeID]
        var visited = Set<NodeID>([rootNodeID])
        
        while !queue.isEmpty {
            let currentID = queue.removeFirst()
            
            if let children = childrenMap[currentID] {
                for childID in children {
                    guard !visited.contains(childID) else { continue }
                    visited.insert(childID)
                    
                    if let childNode = nodes.first(where: { $0.id == childID }) {
                        segmentNodes.append(childNode.unwrapped)
                        queue.append(childID)
                    }
                }
            }
        }
        
        return segmentNodes
    }
}
