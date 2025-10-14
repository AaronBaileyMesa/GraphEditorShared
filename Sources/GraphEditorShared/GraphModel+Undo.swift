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
}

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "graphmodel_undo")
    
    internal func pushUndo() {
        undoStack.append(currentState())
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack = []
    }
    
    private func currentState() -> UndoGraphState {
        UndoGraphState(nodes: nodes, edges: edges, nextLabel: nextNodeLabel)
    }
    
    public func undo(resume: Bool = true) async {
        if let state = undoStack.popLast() {
            redoStack.append(currentState())
            nodes = state.nodes
            edges = state.edges
            nextNodeLabel = state.nextLabel
            objectWillChange.send()
            if resume {
                await resumeSimulation()
            }
        }
    }
    
    public func redo(resume: Bool = true) async {
        if let state = redoStack.popLast() {
            undoStack.append(currentState())
            nodes = state.nodes
            edges = state.edges
            nextNodeLabel = state.nextLabel
            objectWillChange.send()
            if resume {
                await resumeSimulation()
            }
        }
    }
    
    public func snapshot() async {
        logger.debug("snapshot() called from: \(#function), nodes: \(self.nodes.count), edges: \(self.edges.count)")  // Use debug for transient info
        let state = UndoGraphState(nodes: nodes, edges: edges, nextLabel: nextNodeLabel)
        undoStack.append(state)
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack.removeAll()
        
        // Handle auto-save with error logging (fixes warning on await save())
        do {
            try await save()  // Use 'try await' here
        } catch {
            let logger = Logger.forCategory("graphmodel")  // From your standardized logging
            logger.errorLog("Auto-save failed during snapshot", error: error)
            // Optional: If you want user feedback, set viewModel.errorMessage here (e.g., via NotificationCenter)
        }
        
        logger.debug("snapshot() completed; undoStack size: \(self.undoStack.count)")
    }
}
