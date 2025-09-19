//
//  GraphModel+Simulation.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation

@available(iOS 16.0, watchOS 6.0, *)
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
