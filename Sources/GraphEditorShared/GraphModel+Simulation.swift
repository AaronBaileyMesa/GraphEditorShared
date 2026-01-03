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
    public func resumeSimulation(resume: Bool = true) async {  // ← Param unchanged
        Self.logger.debugLog("Resuming simulation")
        physicsEngine.isPaused = false
        let task = await simulator.simulationTask  // ← Await and assign first
        if resume && task == nil {
            await startSimulation()
        }
    }
    
    // NEW: Public wrapper for animated simulation (add at end of class)
    public func runAnimatedSimulation(interval: TimeInterval = 1.0 / 30.0, maxSteps: Int = 300) async {
        await simulator.runAnimatedSimulation(interval: interval, maxSteps: maxSteps)
    }
    
    public func resetVelocityHistory() async {
            await simulator.resetVelocityHistory()
        }

    // ADDED: @MainActor to isolate this method to the main thread
    @MainActor
    public func stopSimulation() async {
        Self.logger.infoLog("Stopping simulation")  // Qualified with Self
        await simulator.stopSimulation()
        isSimulating = false
    }
}
