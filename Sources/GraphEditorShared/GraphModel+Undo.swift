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
        let state = GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges)
        undoStack.append(state)
        if undoStack.count > maxUndo { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    public func undo() async {
        guard let state = undoStack.popLast() else { return }
        redoStack.append(GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges))
        nodes = state.nodes.map { AnyNode($0) }
        edges = state.edges
        objectWillChange.send()
    }

    public func redo() async {
        guard let state = redoStack.popLast() else { return }
        undoStack.append(GraphState(nodes: nodes.map { $0.unwrapped }, edges: edges))
        nodes = state.nodes.map { AnyNode($0) }
        edges = state.edges
        objectWillChange.send()
    }

    public func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) throws {
        // Implement saving logic here
    }

    public func loadViewState() throws -> GraphViewState? {
        // Implement loading logic here
        return nil
    }
}
