//
//  GraphSimulator.swift
//  GraphEditorShared
//
//  Created by handcart on 8/12/25.
//

import Foundation
import os.log  // For logging if needed

#if os(watchOS)
import WatchKit  // Only if using haptics; otherwise remove
#endif

@available(iOS 16.0, watchOS 6.0, *)
/// Manages physics simulation loops for graph updates.
class GraphSimulator {
    var simulationTask: Task<Void, Never>?  // Exposed for testing
    internal var recentVelocities: [CGFloat] = []  // Explicit internal for test access
    let velocityChangeThreshold: CGFloat
    let velocityHistoryCount: Int
    let baseInterval: TimeInterval  // Now configurable
    
    let physicsEngine: PhysicsEngine
    private let getVisibleNodes: () async -> [any NodeProtocol]
    private let getVisibleEdges: () async -> [GraphEdge]
    
    internal let getNodes: () async -> [any NodeProtocol]  // Changed from private to internal
    internal let setNodes: ([any NodeProtocol]) async -> Void  // Updated: Polymorphic
    private let getEdges: () async -> [GraphEdge]
    internal let onStable: (() -> Void)?  // New: Optional callback
    
    init(getNodes: @escaping () async -> [any NodeProtocol],
         setNodes: @escaping ([any NodeProtocol]) async -> Void,
         getEdges: @escaping () async -> [GraphEdge],
         getVisibleNodes: @escaping () async -> [any NodeProtocol],
         getVisibleEdges: @escaping () async -> [GraphEdge],
         physicsEngine: PhysicsEngine,
         onStable: (() -> Void)? = nil,
         baseInterval: TimeInterval = 1.0 / 30.0,  // Default value
         velocityChangeThreshold: CGFloat = 0.01,
         velocityHistoryCount: Int = 5) {
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
    }
    
    struct SimulationStepResult {
        let updatedNodes: [any NodeProtocol]
        let shouldContinue: Bool
        let totalVelocity: CGFloat
    }
    
    @MainActor
    func startSimulation() async {
    #if os(watchOS)
        guard WKApplication.shared().applicationState == .active else { return }
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
    
    func stopSimulation() async {
        simulationTask?.cancel()
        await simulationTask?.value
        simulationTask = nil  // Added: Clear task after stop
    }
    
    internal func runSimulationLoop(baseInterval: TimeInterval, nodeCount: Int) async {
        print("Starting sim loop with nodeCount: \(nodeCount), maxIterations: 500")
        var iterations = 0
        let maxIterations = 500
        while !Task.isCancelled && iterations < maxIterations {
            if physicsEngine.isPaused {
                try? await Task.sleep(for: .milliseconds(100))  // Poll every 100ms; ignore cancellation errors
                continue
            }
            let shouldContinue = await performSimulationStep(baseInterval: baseInterval, nodeCount: nodeCount)
            physicsEngine.alpha *= (1 - Constants.Physics.alphaDecay)
            iterations += 1
            print("Iteration \(iterations): shouldContinue = \(shouldContinue)")
            if !shouldContinue {
                print("Simulation stabilized after \(iterations) iterations")
                break
            }
        }
        if iterations >= maxIterations {
            print("Simulation timed out after \(iterations) iterations; recent velocities: \(recentVelocities)")
        }
        self.onStable?()
    }
    
    internal func performSimulationStep(baseInterval: TimeInterval, nodeCount: Int) async -> Bool {
#if os(watchOS)
        if await WKApplication.shared().applicationState != .active { return false }
#endif
        
        if physicsEngine.isPaused { return false } // Added: Stop loop if paused to prevent infinite loop
        
        let result: SimulationStepResult = await Task.detached {
            await self.computeSimulationStep()
        }.value
        print("Step: Total velocity = \(result.totalVelocity)")
        await self.setNodes(result.updatedNodes)
        
        recentVelocities.append(result.totalVelocity)
        if recentVelocities.count > velocityHistoryCount {
            recentVelocities.removeFirst()
        }
        
        let velocityChange = recentVelocities.max()! - recentVelocities.min()!
        let isStable = velocityChange < velocityChangeThreshold && recentVelocities.allSatisfy { $0 < 0.5 }
        
        return !isStable
    }
    
    internal func computeSimulationStep() async -> SimulationStepResult {
        let nodes = await getNodes()
        let edges = await getEdges()
        
        let (updatedNodes, isActive) = physicsEngine.simulationStep(nodes: nodes, edges: edges)
        let totalVelocity = updatedNodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
        
        return SimulationStepResult(updatedNodes: updatedNodes, shouldContinue: isActive, totalVelocity: totalVelocity)
    }
    
    internal func shouldStopSimulation(result: SimulationStepResult, nodeCount: Int) -> Bool {
        recentVelocities.append(result.totalVelocity)
        if recentVelocities.count > velocityHistoryCount {
            recentVelocities.removeFirst()
        }
        let velocityChange = recentVelocities.max()! - recentVelocities.min()!
        let isStable = velocityChange < velocityChangeThreshold && recentVelocities.allSatisfy { $0 < 0.5 }
        return isStable  // True if should stop (stable and low velocity)
    }
}
