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
actor GraphSimulator {
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
    private let onStable: (() -> Void)?  // New: Optional callback
    
    private let onPostStable: (() -> Void)?
    private let postStableDelay: TimeInterval
    
    private let bypassAppCheck: Bool  // Flag to skip watchOS app state check in tests
        private let testStepDelay: TimeInterval?  // Optional delay per step for test slowing

        init(getNodes: @escaping () async -> [any NodeProtocol],
             setNodes: @escaping ([any NodeProtocol]) async -> Void,
             getEdges: @escaping () async -> [GraphEdge],
             getVisibleNodes: @escaping () async -> [any NodeProtocol],
             getVisibleEdges: @escaping () async -> [GraphEdge],
             physicsEngine: PhysicsEngine,
             onStable: (() -> Void)? = nil,
             onPostStable: (() -> Void)? = nil,
             postStableDelay: TimeInterval = 5.0,
             baseInterval: TimeInterval = 1.0 / 30.0,
             velocityChangeThreshold: CGFloat = 0.01,
             velocityHistoryCount: Int = 5,
             bypassAppCheck: Bool = false,  // ADDED: Default false (normal behavior)
             testStepDelay: TimeInterval? = nil) {  // ADDED: Default nil (no delay)
        self.getNodes = getNodes
        self.setNodes = setNodes
        self.getEdges = getEdges
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
        physicsEngine.resetSimulation()
        recentVelocities.removeAll()
        
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
    
    // ADDED: Now async (actor-isolated)
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
                try? await Task.sleep(for: .milliseconds(100))
                continue
            }
            let shouldContinue = await performSimulationStep(baseInterval: baseInterval, nodeCount: nodeCount)
            physicsEngine.alpha *= (1 - Constants.Physics.alphaDecay)
            iterations += 1
            logger.debug("Iteration \(iterations): shouldContinue = \(shouldContinue)")
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

    private func performSimulationStep(baseInterval: TimeInterval, nodeCount: Int) async -> Bool {
    #if os(watchOS)
        let appState = await WKApplication.shared().applicationState
        if appState != .active { return false }
    #endif
        
        if physicsEngine.isPaused { return false }
        
        #if DEBUG
        let stepState = signposter.beginInterval("SimulationStep", "Nodes: \(nodeCount)")
        #endif
        
        let result: SimulationStepResult = await Task.detached {
            await self.computeSimulationStep()
        }.value
        logger.debug("Step: Total velocity = \(result.totalVelocity)")
        await self.setNodes(result.updatedNodes)
        
        recentVelocities.append(result.totalVelocity)
        if recentVelocities.count > velocityHistoryCount {
            recentVelocities.removeFirst()
        }
        
        let velocityChange = recentVelocities.max()! - recentVelocities.min()!
        let isStable = velocityChange < velocityChangeThreshold && recentVelocities.allSatisfy { $0 < 0.5 }
        
        #if DEBUG
        signposter.endInterval("SimulationStep", stepState, "Total velocity: \(result.totalVelocity), Stable: \(isStable)")
        #endif
        
        return !isStable
    }
    
    private func computeSimulationStep() async -> SimulationStepResult {
        let nodes = await getNodes()
        let edges = await getEdges()
        
        let (updatedNodes, isActive) = physicsEngine.simulationStep(nodes: nodes, edges: edges)
        let totalVelocity = updatedNodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
        
        return SimulationStepResult(updatedNodes: updatedNodes, shouldContinue: isActive, totalVelocity: totalVelocity)
    }
    
    private func shouldStopSimulation(result: SimulationStepResult, nodeCount: Int) async -> Bool {
        recentVelocities.append(result.totalVelocity)
        if recentVelocities.count > velocityHistoryCount {
            recentVelocities.removeFirst()
        }
        let velocityChange = recentVelocities.max()! - recentVelocities.min()!
        let isStable = velocityChange < velocityChangeThreshold && recentVelocities.allSatisfy { $0 < 0.5 }
        return isStable  // True if should stop (stable and low velocity)
    }
}
