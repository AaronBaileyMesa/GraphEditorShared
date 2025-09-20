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
        print("undo() called; undoStack size: \(undoStack.count)")  // Add for debugging
        guard let state = undoStack.popLast() else { return }
        redoStack.append(GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges))
        nodes = state.nodes.map { AnyNode($0) }
        edges = state.edges
        objectWillChange.send()
        await save()  // NEW: Optional auto-save after undo
        print("undo() completed; nodes: \(nodes.count)")  // Add for debugging
    }

    public func redo() async {
        print("redo() called; redoStack size: \(redoStack.count)")  // Add for debugging
        guard let state = redoStack.popLast() else { return }
        undoStack.append(GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges))
        nodes = state.nodes.map { AnyNode($0) }
        edges = state.edges
        objectWillChange.send()
        await save()  // NEW: Optional auto-save after redo
        print("redo() completed; nodes: \(nodes.count)")  // Add for debugging
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
