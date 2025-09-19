// Sources/GraphEditorShared/GraphSimulator.swift

import Foundation
import os.log  // For logging if needed

#if os(watchOS)
import WatchKit  // Only if using haptics; otherwise remove
#endif

@available(iOS 16.0, watchOS 6.0, *)
/// Manages physics simulation loops for graph updates.
class GraphSimulator {
    private var simulationTask: Task<Void, Never>?
    private var recentVelocities: [CGFloat] = []
    private let velocityChangeThreshold: CGFloat = 0.01
    private let velocityHistoryCount = 5
    
    let physicsEngine: PhysicsEngine
    private let getVisibleNodes: () -> [any NodeProtocol]
    private let getVisibleEdges: () -> [GraphEdge]
    
    private let getNodes: () -> [any NodeProtocol]  // Updated: Polymorphic
    private let setNodes: ([any NodeProtocol]) -> Void  // Updated: Polymorphic
    private let getEdges: () -> [GraphEdge]
    private let onStable: (() -> Void)?  // New: Optional callback
    
    init(getNodes: @escaping () -> [any NodeProtocol],
         setNodes: @escaping ([any NodeProtocol]) -> Void,
         getEdges: @escaping () -> [GraphEdge],
         getVisibleNodes: @escaping () -> [any NodeProtocol],
         getVisibleEdges: @escaping () -> [GraphEdge],
         physicsEngine: PhysicsEngine,
         onStable: (() -> Void)? = nil) {  // New parameter
        self.getNodes = getNodes
        self.setNodes = setNodes
        self.getEdges = getEdges
        self.physicsEngine = physicsEngine
        self.onStable = onStable
        
        self.getVisibleNodes = getVisibleNodes
        self.getVisibleEdges = getVisibleEdges
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
        if nodeCount < 5 { return }
        
        var baseInterval: TimeInterval = nodeCount < 20 ? 1.0 / 30.0 : (nodeCount < 50 ? 1.0 / 15.0 : 1.0 / 10.0)
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            baseInterval *= 2.0
        }
        
        simulationTask = Task {
            await self.runSimulationLoop(baseInterval: baseInterval, nodeCount: nodeCount)
        }
        await simulationTask?.value
    }
    
    private func runSimulationLoop(baseInterval: TimeInterval, nodeCount: Int) async {
        while !Task.isCancelled {
            #if os(watchOS)
            if await WKApplication.shared().applicationState != .active { break }
            #endif
            
            let result: SimulationStepResult = await Task.detached {
                return self.computeSimulationStep()
            }.value
            
            self.setNodes(result.updatedNodes)
            
            if self.shouldStopSimulation(result: result, nodeCount: nodeCount) {
                break
            }
            
            try? await Task.sleep(for: .seconds(baseInterval))
        }
        self.onStable?()
    }
    
    private nonisolated func computeSimulationStep() -> SimulationStepResult {
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
    
    private func shouldStopSimulation(result: SimulationStepResult, nodeCount: Int) -> Bool {
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
            let relativeChange = (maxVel - minVel) / maxVel
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
