//
//  GraphModel+Undo.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    public func snapshot() async {
        print("snapshot() called from: \(#function), nodes: \(nodes.count), edges: \(edges.count)")  // Add for debugging
        let state = GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges)
        undoStack.append(state)
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack.removeAll()
        await save()  // NEW: Auto-save graph data on snapshot (triggered by mutations)
        print("snapshot() completed; undoStack size: \(undoStack.count)")  // Add for debugging
    }

    public func undo() async {
        print("undo() called; undoStack size: \(undoStack.count)")  // Debugging
        guard undoStack.count > 1 else {
            print("undo() early return: cannot undo further")
            return
        }
        if let popped = undoStack.popLast() {
            redoStack.append(popped)
            if let previous = undoStack.last {
                nodes = previous.nodes.map { AnyNode($0) }
                edges = previous.edges
                objectWillChange.send()
                await save()  // Auto-save
                print("undo() completed; nodes: \(nodes.count), undoStack size: \(undoStack.count), redoStack size: \(redoStack.count)")  // Debugging
            }
        }
    }
    
    public func redo() async {
        print("redo() called; redoStack size: \(redoStack.count)")  // Debugging
        guard let state = redoStack.popLast() else { return }
        nodes = state.nodes.map { AnyNode($0) }
        edges = state.edges
        undoStack.append(state)
        objectWillChange.send()
        await save()  // Auto-save
        print("redo() completed; nodes: \(nodes.count), undoStack size: \(undoStack.count), redoStack size: \(redoStack.count)")  // Debugging (updated to include stacks)
    }

    public func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) async throws {
        print("GraphModel.saveViewState called with offset: \(offset), zoom: \(zoomScale)")  // Add for debugging
        let viewState = ViewState(offset: offset, zoomScale: zoomScale, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
        try await storage.saveViewState(viewState)  // Delegate to storage (e.g., UserDefaults)
    }

    public func loadViewState() async throws -> ViewState? {
        print("GraphModel.loadViewState called")  // Add for debugging
        return try await storage.loadViewState()  // Delegate to storage
    }
}
