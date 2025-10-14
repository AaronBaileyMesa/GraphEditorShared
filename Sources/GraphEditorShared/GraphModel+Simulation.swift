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
        logger.infoLog("Starting simulation")  // Added info log
        isSimulating = true
        isStable = false
        await simulator.startSimulation()
    }

    public func pauseSimulation() async {
        logger.debugLog("Pausing simulation")  // Added debug log
        physicsEngine.isPaused = true
    }

    public func resumeSimulation() async {
        logger.debugLog("Resuming simulation")  // Added debug log
        physicsEngine.isPaused = false
        if simulator.simulationTask == nil {
            await startSimulation()
        }
    }

    public func stopSimulation() async {
        logger.infoLog("Stopping simulation")  // Added info log
        await simulator.stopSimulation()
        isSimulating = false
    }
}
