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
    fileprivate static let simulationLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "GraphEditorShared", category: "simulation")
    
    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
    public func startSimulation() async {
        Self.logger.infoLog("Starting simulation")  // Qualified with Self
        isSimulating = true
        isStable = false
        await simulator.startSimulation()
    }

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
    public func pauseSimulation() async {
        Self.logger.debugLog("Pausing simulation")  // Qualified with Self
        physicsEngine.isPaused = true
    }

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
    public func resumeSimulation() async {
        Self.logger.debugLog("Resuming simulation")  // Qualified with Self
        physicsEngine.isPaused = false
        if await simulator.simulationTask == nil {
            await startSimulation()
        }
    }

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
    public func stopSimulation() async {
        Self.logger.infoLog("Stopping simulation")  // Qualified with Self
        await simulator.stopSimulation()
        isSimulating = false
    }
}
