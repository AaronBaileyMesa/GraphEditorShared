// Sources/GraphEditorShared/GraphSimulator.swift

import Foundation
import os.log  // For logging if needed

#if os(watchOS)
import WatchKit  // Only if using haptics; otherwise remove
#endif

@available(iOS 13.0, watchOS 6.0, *)
/// Manages physics simulation loops for graph updates.
class GraphSimulator {
    private var timer: Timer? = nil  // Ensure this declaration is here
    private var recentVelocities: [CGFloat] = []
    private let velocityChangeThreshold: CGFloat = 0.01
    private let velocityHistoryCount = 5
    
    let physicsEngine: PhysicsEngine
    private let getNodes: () -> [any NodeProtocol]  // Updated: Polymorphic
    private let setNodes: ([any NodeProtocol]) -> Void  // Updated: Polymorphic
    private let getEdges: () -> [GraphEdge]
    private let onStable: (() -> Void)?  // New: Optional callback
    
    init(getNodes: @escaping () -> [any NodeProtocol],
         setNodes: @escaping ([any NodeProtocol]) -> Void,
         getEdges: @escaping () -> [GraphEdge],
         physicsEngine: PhysicsEngine,
         onStable: (() -> Void)? = nil) {  // New parameter
        self.getNodes = getNodes
        self.setNodes = setNodes
        self.getEdges = getEdges
        self.physicsEngine = physicsEngine
        self.onStable = onStable
    }
    
    func startSimulation(onUpdate: @escaping () -> Void) {
            timer?.invalidate()
            physicsEngine.resetSimulation()
            recentVelocities.removeAll()
            
            let nodeCount = getNodes().count
            if nodeCount < 5 { return }
            
            // Dynamic interval: Slower for larger graphs; further slow in low power mode
            var baseInterval: TimeInterval = nodeCount < 20 ? 1.0 / 30.0 : (nodeCount < 50 ? 1.0 / 15.0 : 1.0 / 10.0)
            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                baseInterval *= 2.0  // Double interval to save battery
            }
            
            timer = Timer.scheduledTimer(withTimeInterval: baseInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
            
            DispatchQueue.global(qos: .userInitiated).async {
                var nodes = self.getNodes()  // [any NodeProtocol]
                let edges = self.getEdges()
                var shouldContinue = false
                let subSteps = nodes.count < 10 ? 5 : (nodes.count < 30 ? 3 : 1)
                
                for _ in 0..<subSteps {
                    let (updatedNodes, stepActive) = self.physicsEngine.simulationStep(nodes: nodes, edges: edges)  // Updated: Non-inout
                    nodes = updatedNodes  // Assign updated
                    shouldContinue = shouldContinue || stepActive  // Accumulate
                }
                
                let totalVelocity = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }  // Uses protocol velocity
                
                DispatchQueue.main.async {
                    self.setNodes(nodes)
                    onUpdate()
                    
                    // Early stop if already stable
                    if !shouldContinue || totalVelocity < Constants.Physics.velocityThreshold * CGFloat(nodes.count) {
                        self.stopSimulation()
                        self.onStable?()  // New: Call when stable
                        return
                    }
                    self.recentVelocities.append(totalVelocity)
                    if self.recentVelocities.count > self.velocityHistoryCount {
                        self.recentVelocities.removeFirst()
                    }
                    
                    if self.recentVelocities.count == self.velocityHistoryCount {
                        let maxVel = self.recentVelocities.max() ?? 1.0
                        let minVel = self.recentVelocities.min() ?? 0.0
                        let relativeChange = (maxVel - minVel) / maxVel
                        // In the relativeChange check, also call onStable on stop
                        if relativeChange < self.velocityChangeThreshold {
                            self.stopSimulation()
                            self.onStable?()  // New
                            return
                        }
                    }
                }
            }
        }
    }
    
    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }
}
