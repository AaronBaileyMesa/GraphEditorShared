//
//  MockGraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 11/6/25.
//

import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

class MockGraphStorage: GraphStorage {
    // In-memory multi-graph storage using full GraphState (includes colors)
    private var graphs: [String: GraphState] = [:]
    private var viewStates: [String: ViewState] = [:]
    private let defaultName = "default"
    
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
    
    var savedViewState: ViewState? {
        get { viewStates[defaultName] }
        set { viewStates[defaultName] = newValue }
    }
    
    // MARK: - Single-graph (default) methods (using default graph under the hood)
    func save(nodes: [any NodeProtocol], edges: [GraphEdge]) async throws {
        let currentState = graphs[defaultName] ?? GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white), isSimulating: false)
        let wrappedNodes = nodes.map { $0 as? AnyNode ?? AnyNode($0) }  // Safe wrap: reuse if already AnyNode
        let updatedState = GraphState(
            nodes: wrappedNodes,
            edges: edges,
            hierarchyEdgeColor: currentState.hierarchyEdgeColor,
            associationEdgeColor: currentState.associationEdgeColor, isSimulating: false
        )
        graphs[defaultName] = updatedState
    }
    
    func load() async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        guard let state = graphs[defaultName] else {
            throw GraphStorageError.graphNotFound(defaultName)
        }
        return (state.nodes, state.edges)
    }
    
    func clear() async throws {  // Clear all for full reset in tests
        graphs.removeAll()
        viewStates.removeAll()
    }
    
    func saveViewState(_ viewState: ViewState) async throws {
        viewStates[defaultName] = viewState
    }
    
    func loadViewState() async throws -> ViewState? {
        return viewStates[defaultName]
    }
    
    // MARK: - Multi-graph methods
    func listGraphNames() async throws -> [String] {
        return Array(graphs.keys).sorted()
    }
    
    func createNewGraph(name: String) async throws {
        if graphs[name] != nil {
            throw GraphStorageError.graphExists(name)
        }
        graphs[name] = GraphState(nodes: [], edges: [], hierarchyEdgeColor: CodableColor(.blue), associationEdgeColor: CodableColor(.white), isSimulating: false)
        viewStates.removeValue(forKey: name)
    }
    
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
    
    func deleteGraph(name: String) async throws {
        guard graphs.removeValue(forKey: name) != nil else {
            throw GraphStorageError.graphNotFound(name)
        }
        viewStates.removeValue(forKey: name)
    }
    
    // MARK: - View state per graph (synchronous variants required by protocol)
    func saveViewState(_ viewState: ViewState, for name: String) throws {
        viewStates[name] = viewState
    }
    
    func loadViewState(for name: String) throws -> ViewState? {
        return viewStates[name]
    }
    
    // MARK: - GraphState methods (now fully implemented)
    public func saveGraphState(_ graphState: GraphState, for name: String) async throws {
        graphs[name] = graphState
    }

    public func loadGraphState(for name: String) async throws -> GraphState {
        guard let state = graphs[name] else {
            throw GraphStorageError.graphNotFound(name)
        }
        return state
    }
}
