//
//  GraphSimulator.swift
//  GraphEditorShared
//
//  Created by handcart on 8/12/25.
//

import Foundation
import os  // For logging and signposts

#if os(watchOS)
import WatchKit  // Only if using haptics; otherwise remove
#endif

@available(iOS 16.0, watchOS 6.0, *)
public actor GraphSimulator {
    private let logger = Logger.forCategory("graphsimulator")  // Added: Define logger instance
    
#if DEBUG
    private let signposter: OSSignposter = {
        let subsystem = "io.handcart.GraphEditor"  // Match your app's subsystem
        return OSSignposter(subsystem: subsystem, category: "graphsimulator")
    }()
#endif
    
    var simulationTask: Task<Void, Never>?  // Exposed for testing
    private var recentVelocities: [CGFloat] = []  // Changed from internal to private (actor isolates it)
    let velocityChangeThreshold: CGFloat
    let velocityHistoryCount: Int
    let baseInterval: TimeInterval  // Now configurable
    
    let physicsEngine: PhysicsEngine
    private let getVisibleNodes: () async -> [any NodeProtocol]
    private let getVisibleEdges: () async -> [GraphEdge]
    
    private let getNodes: () async -> [any NodeProtocol]  // Changed from internal to private
    private let setNodes: ([any NodeProtocol]) async -> Void  // Updated: Polymorphic
    private let getEdges: () async -> [GraphEdge]
    private let getDraggedNodeID: () async -> NodeID?  // NEW: Get currently dragged node to exclude from physics
    private let onStable: (() -> Void)?  // New: Optional callback
    
    private let onPostStable: (() -> Void)?
    private let postStableDelay: TimeInterval
    
    private let bypassAppCheck: Bool  // Flag to skip watchOS app state check in tests
    private let testStepDelay: TimeInterval?  // Optional delay per step for test slowing
    
    init(getNodes: @escaping () async -> [any NodeProtocol],
         setNodes: @escaping ([any NodeProtocol]) async -> Void,
         getEphemerals: @escaping () async -> [any NodeProtocol] = { [] },  // Default: empty array (no-op)
         setEphemerals: @escaping ([any NodeProtocol]) async -> Void = { _ in },  // Default: ignore input (no-op)
         getEdges: @escaping () async -> [GraphEdge],
         getVisibleNodes: @escaping () async -> [any NodeProtocol],
         getVisibleEdges: @escaping () async -> [GraphEdge],
         getDraggedNodeID: @escaping () async -> NodeID? = { nil },  // NEW: Default returns nil
         physicsEngine: PhysicsEngine,
         onStable: (() -> Void)? = nil,
         onPostStable: (() -> Void)? = nil,
         postStableDelay: TimeInterval = 5.0,
         baseInterval: TimeInterval = 1.0 / 30.0,
         velocityChangeThreshold: CGFloat = 0.04,
         velocityHistoryCount: Int = 30,
         bypassAppCheck: Bool = false,  // ADDED: Default false (normal behavior)
         testStepDelay: TimeInterval? = nil) {  // ADDED: Default nil (no delay)
        self.getNodes = getNodes
        self.setNodes = setNodes
        self.getEdges = getEdges
        self.getEphemerals = getEphemerals  // NEW
        self.setEphemerals = setEphemerals  // NEW
        self.getDraggedNodeID = getDraggedNodeID  // NEW
        self.physicsEngine = physicsEngine
        self.onStable = onStable
        
        self.getVisibleNodes = getVisibleNodes
        self.getVisibleEdges = getVisibleEdges
        
        self.baseInterval = baseInterval
        self.velocityChangeThreshold = velocityChangeThreshold
        self.velocityHistoryCount = velocityHistoryCount
        
        self.onPostStable = onPostStable
        self.postStableDelay = postStableDelay
        self.bypassAppCheck = bypassAppCheck
        self.testStepDelay = testStepDelay
    }
    
    private let getEphemerals: () async -> [any NodeProtocol]  // NEW
    private let setEphemerals: ([any NodeProtocol]) async -> Void  // NEW
    
    struct SimulationStepResult {
        let updatedNodes: [any NodeProtocol]
        let shouldContinue: Bool
        let totalVelocity: CGFloat
    }
    
    func startSimulation() async {
#if os(watchOS)
        if !bypassAppCheck {  // ADDED: Only check if not bypassed
            let appState = await WKApplication.shared().applicationState
            guard appState == .active else { return }
        }
#endif
        recentVelocities.removeAll()      // ← AND THIS ONE (optional, but harmless to keep if you want fresh history)
        
        let nodeCount = await getNodes().count
        if nodeCount < 5 {
            onStable?()  // NEW: Call here to handle "already stable" cases
            return
        }
        
        var adjustedInterval = baseInterval
        if nodeCount >= 20 {
            adjustedInterval = nodeCount < 50 ? 1.0 / 15.0 : 1.0 / 10.0
        }
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            adjustedInterval *= 2.0
        }
        
        simulationTask = Task {
            await self.runSimulationLoop(baseInterval: adjustedInterval, nodeCount: nodeCount)
            self.simulationTask = nil  // Clear after completion (moved inside Task)
        }
    }
    
    // ADDED: Now async (actor-isolated)
    func stopSimulation() async {
        simulationTask?.cancel()
        simulationTask = nil
    }
    
    // MARK: - Public API for GraphModel
    
    /// Call this whenever the set of visible nodes changes significantly
    /// (e.g. ToggleNode collapse/expand, hierarchy edge add/delete, undo/redo, load graph)
    public func resetVelocityHistory() async {
        self.clearVelocityHistory()
    }
    
    private func clearVelocityHistory() {
        recentVelocities.removeAll(keepingCapacity: true)
        logger.debug("Velocity history cleared – graph visibility changed")
    }
    
    private func runSimulationLoop(baseInterval: TimeInterval, nodeCount: Int) async {
        let startTime = Date()
#if DEBUG
        let loopState = signposter.beginInterval("SimulationLoop", "Nodes: \(nodeCount)")
#endif
        
        let maxIterations = 500  // Arbitrary limit to prevent infinite loops
        var iterations = 0
        
        while !Task.isCancelled && iterations < maxIterations {
            // ADDED: Optional test delay for slowing loop (e.g., for reliability)
            if let delay = testStepDelay {
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            } else {
                try? await Task.sleep(for: .seconds(baseInterval))
            }
            if physicsEngine.isPaused {
                logger.debug(">>> Simulation loop: isPaused = true, sleeping...")
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }
            logger.debug(">>> Simulation loop: about to call performSimulationStep")
            let shouldContinue = await performSimulationStep(baseInterval: baseInterval, nodeCount: nodeCount)
            physicsEngine.alpha *= (1 - Constants.Physics.alphaDecay)
            iterations += 1
            logger.info("Iteration \(iterations): shouldContinue = \(shouldContinue) | recentVelocities = \(self.recentVelocities.map { String(format: "%.3f", $0) }.joined(separator: ", "))")
            if !shouldContinue {
                logger.info("Simulation stabilized after \(iterations) iterations")
#if DEBUG
                signposter.endInterval("SimulationLoop", loopState, "Stabilized after \(iterations) iterations")
#endif
                break
            }
        }
        
        if iterations < maxIterations && !Task.isCancelled {
            logger.info("Simulation stabilized; waiting \(self.postStableDelay)s for inactivity pause")
            try? await Task.sleep(for: .seconds(postStableDelay))
            if !Task.isCancelled {
                onPostStable?()
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)  // Added for perf
        if iterations >= maxIterations {
            logger.warning("Simulation timed out after \(iterations) iterations; recent velocities: \(self.recentVelocities); duration: \(duration)s")
#if DEBUG
            signposter.endInterval("SimulationLoop", loopState, "Timed out after \(iterations) iterations")
            signposter.emitEvent("SimulationTimeout", "Recent velocities: \(self.recentVelocities)")
#endif
        }
        self.onStable?()
    }
    
    // Replace the entire performSimulationStep function with this version
    // (It includes the safe write-back logic, integrates ephemerals, and fits the current init params)

    // Rationale: Single cohesive simulation step including physics, stability checking, and node updates
    // swiftlint:disable:next function_body_length
    func performSimulationStep(baseInterval: TimeInterval, nodeCount: Int) async -> Bool {
#if DEBUG
        let stepState = signposter.beginInterval("SimulationStep")
#endif
        
        logger.debug(">>> performSimulationStep called with nodeCount: \(nodeCount)")

        // NEW: Adaptive interval based on node count (e.g., slower for large graphs)
        _ = baseInterval * (1.0 + CGFloat(log(max(Double(nodeCount), 1.0))))

        let visibleNodes = await getVisibleNodes()
        let visibleEdges = await getVisibleEdges()
        
        // Build fixedIDs: control nodes + their owner + dragged node (to prevent physics from moving them during drag)
        var fixedIDs = Set<NodeID>()
        var ownerIDs = Set<NodeID>()
        
        let controlNodeCount = visibleNodes.filter { $0 is ControlNode }.count
        logger.debug("Building fixedIDs: found \(controlNodeCount) control nodes in \(visibleNodes.count) visible nodes")
        
        for node in visibleNodes where node is ControlNode {
            fixedIDs.insert(node.id)
            if let control = node as? ControlNode, let ownerID = control.ownerID {
                ownerIDs.insert(ownerID)
                logger.debug("Control node \(node.id.uuidString.prefix(8)) has owner \(ownerID.uuidString.prefix(8))")
            }
        }
        // Fix owner nodes too - they should not move while their control nodes are visible
        for ownerID in ownerIDs {
            fixedIDs.insert(ownerID)
        }
        if let draggedID = await getDraggedNodeID() {
            fixedIDs.insert(draggedID)
        }
        
        if !ownerIDs.isEmpty {
            logger.debug("Fixed owner nodes: \(ownerIDs.map { $0.uuidString.prefix(8) }.joined(separator: ", "))")
            logger.debug("Total fixed nodes: \(fixedIDs.count) (includes \(ownerIDs.count) owners and their control nodes)")
        }
        
        let (updatedVisibleNodes, _) = physicsEngine.simulationStep(nodes: visibleNodes, edges: visibleEdges, fixedIDs: fixedIDs)
        // let totalVelocity = updatedVisibleNodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
        
        // Removed stray debug line that referenced self.stepCount, self.engine, and finalStable before declaration
        
        // Safe write-back with duplicate handling
        let currentPersistent = await getNodes()
        let currentEphemerals = await getEphemerals()
        
        var nodeMap: [NodeID: any NodeProtocol] = [:]
        
        for node in currentPersistent {
            if nodeMap[node.id] != nil {
                logger.error("Duplicate in persistent nodes: \(node.id)")
            } else {
                nodeMap[node.id] = node
            }
        }
        
        for node in currentEphemerals {
            if nodeMap[node.id] != nil {
                logger.error("Duplicate between persistent and ephemeral: \(node.id)")
            } else {
                nodeMap[node.id] = node
            }
        }
        
        // CRITICAL: For control nodes, preserve their ORIGINAL positions from before physics
        // They should never be moved by simulation
        let controlNodesBefore = await getEphemerals()
        var controlPositions: [NodeID: CGPoint] = [:]
        for control in controlNodesBefore {
            controlPositions[control.id] = control.position
        }
        
        for updatedNode in updatedVisibleNodes {
            // If this is a control node, restore its original position
            if let originalPos = controlPositions[updatedNode.id] {
                var fixedControl = updatedNode
                fixedControl.position = originalPos
                fixedControl.velocity = .zero
                nodeMap[updatedNode.id] = fixedControl
                #if DEBUG
                if updatedNode.position != originalPos {
                    logger.debug("FIXED control node \(updatedNode.id.uuidString.prefix(8)): physics moved it from \(originalPos.x, format: .fixed(precision: 1)),\(originalPos.y, format: .fixed(precision: 1)) to \(updatedNode.position.x, format: .fixed(precision: 1)),\(updatedNode.position.y, format: .fixed(precision: 1)) - restoring original")
                }
                #endif
            } else {
                nodeMap[updatedNode.id] = updatedNode
            }
        }
        
        var newPersistent: [any NodeProtocol] = []
        var newEphemerals: [any NodeProtocol] = []
        
        for (_, node) in nodeMap {
            if node is ControlNode {
                newEphemerals.append(node)
            } else {
                newPersistent.append(node)
            }
        }
        
        await setNodes(newPersistent)
        await setEphemerals(newEphemerals)
        
        let totalVelocity = updatedVisibleNodes.reduce(0.0) { $0 + $1.velocity.magnitude }

            // Existing log (kept for reference)
            logger.debug("Step: Total velocity = \(totalVelocity) (visible: \(visibleNodes.count))")
            
            recentVelocities.append(totalVelocity)
            if recentVelocities.count > velocityHistoryCount {
                recentVelocities.removeFirst()
            }
        
        let absoluteVelocityThreshold: CGFloat = 0.065   // TUNABLE: 0.04 = rock solid, 0.08 = slightly forgiving
            let requiredStableSamples: Int = 20              // Must stay below threshold for N consecutive steps
            
            let recentCount = recentVelocities.count
            let allBelowThreshold = recentVelocities.allSatisfy { $0 < absoluteVelocityThreshold }
            let enoughSamples = recentCount >= requiredStableSamples
            
            let isStable = enoughSamples && allBelowThreshold
            
            // Optional: Add a tiny velocity change check as secondary confirmation (prevents oscillation)
            let velocityChange = recentVelocities.max()! - recentVelocities.min()!
            let isNearlyFlat = velocityChange < 0.04
            
            let finalStable = isStable && isNearlyFlat
            
            // NEW: Added logging here to confirm root cause (includes all computed values)
            logger.debug("Step \(self.physicsEngine.stepCount): Total Velocity = \(totalVelocity) | Alpha = \(self.physicsEngine.alpha) | Recent Min/Max = \(self.recentVelocities.min() ?? 0)/\(self.recentVelocities.max() ?? 0) | Stable? \(finalStable)")
            
            // Existing log (kept for reference)
            logger.debug("Step: Total velocity = \(totalVelocity) (visible: \(visibleNodes.count)) | Stable: \(finalStable) (samples: \(recentCount)/\(requiredStableSamples), maxV: \(self.recentVelocities.max() ?? 0))")
            
#if DEBUG
        signposter.endInterval("SimulationStep", stepState,
                               "Vel: \(String(format: "%.3f", totalVelocity)), Stable: \(finalStable), Samples: \(recentCount)/\(requiredStableSamples)")
#endif
        
        return !finalStable
    }
    // In GraphSimulator.swift (add this public method to the actor)
    public func runShortSimulation(steps: Int, interval: TimeInterval = 1.0 / 60.0) async {
        for _ in 0..<steps {
#if os(watchOS)
            if !bypassAppCheck {
                let appState = await WKApplication.shared().applicationState
                guard appState == .active else { return }
            }
#endif
            let shouldContinue = await performSimulationStep(baseInterval: interval, nodeCount: await getVisibleNodes().count)
            if !shouldContinue { break }  // Early exit if stable
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }
    
    // NEW: Runs simulation indefinitely until stable, with timed intervals for animation (e.g., 30 FPS)
    public func runAnimatedSimulation(interval: TimeInterval = 1.0 / 30.0, maxSteps: Int = 300) async {
        var step = 0
        while step < maxSteps {
    #if os(watchOS)
            if !bypassAppCheck {
                let appState = await WKApplication.shared().applicationState
                guard appState == .active else { return }
            }
    #endif
            let nodeCount = await getVisibleNodes().count
            let shouldContinue = await performSimulationStep(baseInterval: interval, nodeCount: nodeCount)
            if !shouldContinue { break }  // Early exit if stable (uses your velocity checks)
            
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))  // Pause for next frame
            
            step += 1
        }
        // Optional: Call onStable or onPostStable if needed (already in performSimulationStep)
    }
    
    public func resetVelocityHistory() {
        recentVelocities = []
    }
}
