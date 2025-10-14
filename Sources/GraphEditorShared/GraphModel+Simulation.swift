//
//  GraphModel+Simulation.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation
import os  // ADDED: For Logger

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    private static let logger = Logger.forCategory("graphmodel-simulation")  // ADDED: Local static logger for this extension

    public func startSimulation() async {
        Self.logger.infoLog("Starting simulation")  // Qualified with Self
        isSimulating = true
        isStable = false
        await simulator.startSimulation()
    }

    public func pauseSimulation() async {
        Self.logger.debugLog("Pausing simulation")  // Qualified with Self
        physicsEngine.isPaused = true
    }

    public func resumeSimulation() async {
        Self.logger.debugLog("Resuming simulation")  // Qualified with Self
        physicsEngine.isPaused = false
        if simulator.simulationTask == nil {
            await startSimulation()
        }
    }

    public func stopSimulation() async {
        Self.logger.infoLog("Stopping simulation")  // Qualified with Self
        await simulator.stopSimulation()
        isSimulating = false
    }
}
