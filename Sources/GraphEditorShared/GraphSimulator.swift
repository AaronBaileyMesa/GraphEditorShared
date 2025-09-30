// Sources/GraphEditorShared/GraphSimulator.swift

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
    private let getVisibleNodes: () -> [any NodeProtocol]
    private let getVisibleEdges: () -> [GraphEdge]
    
    internal let getNodes: () -> [any NodeProtocol]  // Changed from private to internal
    private let setNodes: ([any NodeProtocol]) -> Void  // Updated: Polymorphic
    private let getEdges: () -> [GraphEdge]
    private let onStable: (() -> Void)?  // New: Optional callback
    
    init(getNodes: @escaping () -> [any NodeProtocol],
         setNodes: @escaping ([any NodeProtocol]) -> Void,
         getEdges: @escaping () -> [GraphEdge],
         getVisibleNodes: @escaping () -> [any NodeProtocol],
         getVisibleEdges: @escaping () -> [GraphEdge],
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
        
        let nodeCount = getNodes().count
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
        }
        await simulationTask?.value
    }
    
    internal func runSimulationLoop(baseInterval: TimeInterval, nodeCount: Int) async {
        print("Starting sim loop with nodeCount: \(nodeCount), maxIterations: 500")  // NEW: Confirm entry
        var iterations = 0
        let maxIterations = 500
        while !Task.isCancelled && iterations < maxIterations {
            let shouldContinue = await performSimulationStep(baseInterval: baseInterval, nodeCount: nodeCount)
            iterations += 1
            print("Iteration \(iterations): shouldContinue = \(shouldContinue)")  // NEW: Per-iter log
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
    
    private func performSimulationStep(baseInterval: TimeInterval, nodeCount: Int) async -> Bool {
#if os(watchOS)
        if await WKApplication.shared().applicationState != .active { return false }
#endif
        
        let result: SimulationStepResult = await Task.detached {
            return self.computeSimulationStep()
        }.value
        print("Step: Total velocity = \(result.totalVelocity)")
        self.setNodes(result.updatedNodes)
        
        if self.shouldStopSimulation(result: result, nodeCount: nodeCount) {
            return false
        }
        
        try? await Task.sleep(for: .seconds(baseInterval))
        return true
    }
    
    nonisolated func computeSimulationStep() -> SimulationStepResult {
        let nodes = self.getNodes()
        let visibleNodes = self.getVisibleNodes()
        let visibleEdges = self.getVisibleEdges()
        let (forces, quadtree) = self.physicsEngine.repulsionCalculator.computeRepulsions(nodes: visibleNodes)
        var updatedForces = forces
        updatedForces = self.physicsEngine.attractionCalculator.applyAttractions(forces: updatedForces, edges: visibleEdges, nodes: visibleNodes)
        updatedForces = self.physicsEngine.centeringCalculator.applyCentering(forces: updatedForces, nodes: visibleNodes)
        
        var tempNodes = nodes
        var stepActive = false
        let subSteps = nodes.count < 5 ? 2 : (nodes.count < 10 ? 5 : (nodes.count < 30 ? 3 : 1))
        for _ in 0..<subSteps {
            let (updated, active) = self.physicsEngine.positionUpdater.updatePositionsAndVelocities(nodes: tempNodes, forces: updatedForces, edges: self.getEdges(), quadtree: quadtree)
            tempNodes = updated
            stepActive = stepActive || active
        }
        
        let totalVel = tempNodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
        return SimulationStepResult(updatedNodes: tempNodes, shouldContinue: stepActive, totalVelocity: totalVel)
    }
    
    func shouldStopSimulation(result: SimulationStepResult, nodeCount: Int) -> Bool {
        print("Check stop: totalVel = \(result.totalVelocity), threshold = \(Constants.Physics.velocityThreshold * CGFloat(nodeCount)), shouldContinue = \(result.shouldContinue)")  // NEW
        if !result.shouldContinue || result.totalVelocity < Constants.Physics.velocityThreshold * CGFloat(nodeCount) {
            return true
        }
        
        recentVelocities.append(result.totalVelocity)
        if recentVelocities.count > velocityHistoryCount {
            recentVelocities.removeFirst()
        }
        
        if recentVelocities.count == velocityHistoryCount {
            let maxVel = recentVelocities.max() ?? 1.0
            let minVel = recentVelocities.min() ?? 0.0
            let relativeChange = (maxVel > 0) ? (maxVel - minVel) / maxVel : 0.0  // Guard zero-divide
            print("Relative change: \(relativeChange) (threshold: \(velocityChangeThreshold))")  // NEW
            if relativeChange < velocityChangeThreshold {
                return true
            }
        }
        
        return false
    }
    
    func stopSimulation() async {
        simulationTask?.cancel()
        await simulationTask?.value  // Await to ensure clean stop
        simulationTask = nil
    }
}
