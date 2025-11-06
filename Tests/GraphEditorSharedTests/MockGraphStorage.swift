//
//  MockGraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 11/6/25.
//


import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

class MockGraphStorage: GraphStorage {
    // In-memory single-graph (default) storage for convenience in tests
    var nodes: [any NodeProtocol] = []
    var edges: [GraphEdge] = []
    var savedViewState: ViewState?
    
    // In-memory multi-graph storage
    private var graphs: [String: (nodes: [any NodeProtocol], edges: [GraphEdge])] = [:]
    private var viewStates: [String: ViewState] = [:]
    private let defaultName = "default"
    
    // MARK: - Single-graph (default) methods
    func save(nodes: [any NodeProtocol], edges: [GraphEdge]) async throws {
        self.nodes = nodes
        self.edges = edges
        // Keep default graph in sync
        graphs[defaultName] = (nodes, edges)
    }
    
    func load() async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        return (nodes, edges)
    }
    
    func clear() async throws {
        nodes = []
        edges = []
        savedViewState = nil
        graphs[defaultName] = ([], [])
        viewStates.removeValue(forKey: defaultName)
    }
    
    func saveViewState(_ viewState: ViewState) async throws {
        savedViewState = viewState
        viewStates[defaultName] = viewState
    }
    
    func loadViewState() async throws -> ViewState? {
        return savedViewState
    }
    
    // MARK: - Multi-graph methods
    func listGraphNames() async throws -> [String] {
        // Always include default; plus any explicitly created graphs
        var names = Set(graphs.keys)
        names.insert(defaultName)
        return Array(names).sorted()
    }
    
    func createNewGraph(name: String) async throws {
        if graphs[name] != nil {
            throw GraphStorageError.graphExists(name)
        }
        graphs[name] = ([], [])
        viewStates.removeValue(forKey: name)
    }
    
    func save(nodes: [any NodeProtocol], edges: [GraphEdge], for name: String) async throws {
        graphs[name] = (nodes, edges)
        if name == defaultName {
            // Keep convenience properties in sync for tests that set/read directly
            self.nodes = nodes
            self.edges = edges
        }
    }
    
    func load(for name: String) async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        if name == defaultName {
            return (nodes, edges)
        }
        if let state = graphs[name] {
            return state
        }
        throw GraphStorageError.graphNotFound(name)
    }
    
    func deleteGraph(name: String) async throws {
        if name == defaultName {
            nodes = []
            edges = []
            savedViewState = nil
            graphs[defaultName] = ([], [])
            viewStates.removeValue(forKey: defaultName)
            return
        }
        guard graphs.removeValue(forKey: name) != nil else {
            throw GraphStorageError.graphNotFound(name)
        }
        viewStates.removeValue(forKey: name)
    }
    
    // MARK: - View state per graph (synchronous variants required by protocol)
    func saveViewState(_ viewState: ViewState, for name: String) throws {
        viewStates[name] = viewState
        if name == defaultName {
            savedViewState = viewState
        }
    }
    
    func loadViewState(for name: String) throws -> ViewState? {
        if name == defaultName {
            return savedViewState ?? viewStates[name]
        }
        return viewStates[name]
    }
}