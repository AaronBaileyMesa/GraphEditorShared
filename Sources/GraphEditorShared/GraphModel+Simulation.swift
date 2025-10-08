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
        await stopSimulation()  // Cancel any ongoing
        isSimulating = true
        isStable = false
        await simulator.startSimulation()
    }
    
    public func pauseSimulation() async {
        await stopSimulation()
    }
    
    public func resumeSimulation() async {
        await startSimulation()
    }
    
    public func stopSimulation() async {
        await simulator.stopSimulation()
        isSimulating = false
    }
}
