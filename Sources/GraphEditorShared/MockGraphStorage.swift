//
//  MockGraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 11/6/25.
//

import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
// import GraphEditorShared  // Standard import (no @testable needed here)

@available(iOS 16.0, watchOS 6.0, *)
public class MockGraphStorage: GraphStorage {
    // In-memory multi-graph storage using full GraphState (includes colors)
    private var graphs: [String: GraphState] = [:]
    private var viewStates: [String: ViewState] = [:]
    private let defaultName = "default"
    
    public init() {}
    
    // Derived single-graph properties for convenience in tests (syncs with default graph)
    var nodes: [any NodeProtocol] {
        get { graphs[defaultName]?.nodes ?? [] }
        set {
            let currentState = graphs[defaultName] ?? GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white), isSimulating: false)
            let wrappedNodes = newValue.map { $0 as? AnyNode ?? AnyNode($0) }  // Safe wrap: reuse if already AnyNode
            let updatedState = GraphState(nodes: wrappedNodes, edges: currentState.edges, hierarchyEdgeColor: currentState.hierarchyEdgeColor, associationEdgeColor: currentState.associationEdgeColor, isSimulating: false)
            graphs[defaultName] = updatedState
        }
    }
    
    var edges: [GraphEdge] {
        get { graphs[defaultName]?.edges ?? [] }
        set {
            let currentState = graphs[defaultName] ?? GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white), isSimulating: false)
            let updatedState = GraphState(nodes: currentState.nodes, edges: newValue, hierarchyEdgeColor: currentState.hierarchyEdgeColor, associationEdgeColor: currentState.associationEdgeColor, isSimulating: false)
            graphs[defaultName] = updatedState
        }
    }
    
    // MARK: - Protocol conformance
    public func saveGraphState(_ graphState: GraphState, for name: String) async throws {
        graphs[name] = graphState
    }

    public func loadGraphState(for name: String) async throws -> GraphState {
        guard let state = graphs[name] else {
            throw GraphStorageError.graphNotFound(name)
        }
        return state
    }
    
    public func clear() async throws {
        // No-op for mock: Clear default graph
        graphs[defaultName] = GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white), isSimulating: false)
        viewStates[defaultName] = nil
    }
    
    public func saveViewState(_ viewState: ViewState, for name: String) throws {
        viewStates[name] = viewState
    }
    
    public func loadViewState(for name: String) throws -> ViewState? {
        return viewStates[name]
    }
    
    public func listGraphNames() async throws -> [String] {
        return Array(graphs.keys)
    }
    
    public func createNewGraph(name: String) async throws {
        if graphs[name] != nil {
            throw GraphStorageError.graphExists(name)
        }
        graphs[name] = GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white), isSimulating: false)
    }
    
    public func deleteGraph(name: String) async throws {
        guard graphs.removeValue(forKey: name) != nil else {
            throw GraphStorageError.graphNotFound(name)
        }
        viewStates.removeValue(forKey: name)
    }
    
    // MARK: - Test helpers (unchanged)
    func save(nodes: [any NodeProtocol], edges: [GraphEdge], for name: String) async throws {
        let currentState = graphs[name] ?? GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white), isSimulating: false)
        let wrappedNodes = nodes.map { $0 as? AnyNode ?? AnyNode($0) }  // Safe wrap: reuse if already AnyNode
        let updatedState = GraphState(
            nodes: wrappedNodes,
            edges: edges,
            hierarchyEdgeColor: currentState.hierarchyEdgeColor,
            associationEdgeColor: currentState.associationEdgeColor, isSimulating: false
        )
        graphs[name] = updatedState
    }
    
    func load(for name: String) async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        guard let state = graphs[name] else {
            throw GraphStorageError.graphNotFound(name)
        }
        return (state.nodes, state.edges)
    }
}
