//
//  GraphModel+Simulation.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    public func startSimulation() async {
        // Remove await stopSimulation() to avoid always canceling; caller should stop explicitly if needed
        isSimulating = true
        isStable = false
        await simulator.startSimulation()
    }
    
    public func pauseSimulation() async {
        physicsEngine.isPaused = true  // Set flag to pause loop without canceling task
    }
    
    public func resumeSimulation() async {
        physicsEngine.isPaused = false  // Unpause; loop will continue if task exists
        if simulator.simulationTask == nil {
            await startSimulation()  // Start new if no task (e.g., after full stop or initial)
        }
    }
    
    public func stopSimulation() async {
        await simulator.stopSimulation()
        isSimulating = false
    }
}
