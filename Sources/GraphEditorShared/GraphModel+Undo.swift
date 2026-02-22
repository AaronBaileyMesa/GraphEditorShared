//
//  GraphModel+Undo.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation
import os

struct UndoGraphState {
    let nodes: [AnyNode]
    let edges: [GraphEdge]
    let nextLabel: Int
    let segmentConfigs: [NodeID: SegmentConfig]
}

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    fileprivate static let undoLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "GraphEditorShared", category: "undo")
    
    public func pushUndo() {
        undoStack.append(currentState())
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack = []
    }
    
    private func currentState() -> UndoGraphState {
        UndoGraphState(nodes: nodes, edges: edges, nextLabel: nextNodeLabel, segmentConfigs: segmentConfigs)
    }
    
    public func undo(resume: Bool = true) async {
        // Stop simulation first to capture stable state
        let wasSimulating = isSimulating
        if wasSimulating {
            await stopSimulation()
        }
        
        if let state = undoStack.popLast() {
            // Capture current state for redo AFTER stopping simulation
            redoStack.append(currentState())
            
            // Restore previous state
            nodes = state.nodes
            edges = state.edges
            segmentConfigs = state.segmentConfigs
            // FIXED: Don't restore nextNodeLabel - it should never decrease to prevent duplicate labels
            // nextNodeLabel = state.nextLabel
            objectWillChange.send()
            
            zeroAllVelocities()
            invalidateHiddenNodesCache()
            await simulator.resetVelocityHistory()
            
            Self.undoLogger.debug("Undo: restored \(state.nodes.count) nodes, \(state.edges.count) edges")
        }
        
        // Resume simulation if it was running and requested
        if resume && wasSimulating {
            await startSimulation()
        }
    }

    public func redo(resume: Bool = true) async {
        // Stop simulation first to capture stable state
        let wasSimulating = isSimulating
        if wasSimulating {
            await stopSimulation()
        }
        
        if let state = redoStack.popLast() {
            // Capture current state for undo AFTER stopping simulation
            undoStack.append(currentState())
            if undoStack.count > maxUndo {
                undoStack.removeFirst()
            }
            
            // Restore redo state
            nodes = state.nodes
            edges = state.edges
            segmentConfigs = state.segmentConfigs
            // FIXED: Don't restore nextNodeLabel - it should never decrease to prevent duplicate labels
            // nextNodeLabel = state.nextLabel
            objectWillChange.send()
            
            zeroAllVelocities()
            invalidateHiddenNodesCache()
            await simulator.resetVelocityHistory()
            
            Self.undoLogger.debug("Redo: restored \(state.nodes.count) nodes, \(state.edges.count) edges")
        }
        
        // Resume simulation if it was running and requested
        if resume && wasSimulating {
            await startSimulation()
        }
    }
    
    public func snapshot() async {
        Self.logger.debug("snapshot() called from: \(#function), nodes: \(self.nodes.count), edges: \(self.edges.count)")  // Use debug for transient info
        let state = UndoGraphState(nodes: nodes, edges: edges, nextLabel: nextNodeLabel, segmentConfigs: segmentConfigs)
        undoStack.append(state)
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack.removeAll()
        
        // Handle auto-save with error logging (fixes warning on await save())
        do {
            try await saveGraph()  // Use 'try await' here
        } catch {
            let logger = Logger.forCategory("graphmodel")  // From your standardized logging
            logger.errorLog("Auto-save failed during snapshot", error: error)
            // Optional: If you want user feedback, set viewModel.errorMessage here (e.g., via NotificationCenter)
        }
        
        Self.logger.debug("snapshot() completed; undoStack size: \(self.undoStack.count)")
    }
}
