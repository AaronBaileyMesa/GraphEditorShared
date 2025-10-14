//
//  GraphModel+Storage.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation
import CoreGraphics
import os  // Added for Logger

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    private func loadFromStorage(for name: String) async throws {
        logger.infoLog("loadFromStorage started for \(name)")  // Updated to infoLog
        let (loadedNodes, loadedEdges) = try await storage.load(for: name)
        logger.infoLog("loadFromStorage: loaded \(loadedNodes.count) nodes, \(loadedEdges.count) edges for \(name)")  // Updated to infoLog
        self.nodes = loadedNodes.map { AnyNode($0) }
        self.edges = loadedEdges
        self.nextNodeLabel = (nodes.map { $0.unwrapped.label }.max() ?? 0) + 1
    }
    
    public func load() async {
        logger.infoLog("GraphModel.load() called")  // Updated to infoLog
        do {
            try await loadFromStorage(for: currentGraphName)
            syncCollapsedPositions()
            if let viewState = try storage.loadViewState(for: currentGraphName) {  // Updated to named (note: throws, but no await as per storage)
                // Apply view state if needed (e.g., publish or set properties)
                logger.infoLog("Loaded view state: offset \(viewState.offset), zoom \(viewState.zoomScale)")  // Updated to infoLog
            }
            logger.infoLog("GraphModel.load() succeeded; nodes: \(nodes.count), edges: \(edges.count)")  // Updated to infoLog
        } catch {
            logger.errorLog("GraphModel.load() failed: \(error.localizedDescription)", error: error)  // Updated to errorLog with error
        }
    }
    
    public func save() async throws {
        logger.infoLog("GraphModel.save() called; nodes: \(nodes.count), edges: \(edges.count)")  // Updated to infoLog
        do {
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges, for: currentGraphName)
            logger.infoLog("GraphModel.save() succeeded")  // Updated to infoLog
        } catch {
            logger.errorLog("GraphModel.save() failed: \(error.localizedDescription)", error: error)  // Updated to errorLog with error
            throw error  // Re-throw for caller handling
        }
    }
    
    private func syncCollapsedPositions() {
        for parentIndex in 0..<nodes.count {
            if let toggle = nodes[parentIndex].unwrapped as? ToggleNode, !toggle.isExpanded {
                let children = edges.filter { $0.from == nodes[parentIndex].id && $0.type == .hierarchy }.map { $0.target }
                for (index, childID) in children.enumerated() {
                    guard let childIndex = nodes.firstIndex(where: { $0.id == childID }) else { continue }
                    var child = nodes[childIndex]
                    let angle = CGFloat(index) * (2 * .pi / CGFloat(children.count))
                    let jitterX = cos(angle) * 5.0
                    let jitterY = sin(angle) * 5.0
                    child.position = nodes[parentIndex].position + CGPoint(x: jitterX, y: jitterY)
                    child.velocity = .zero
                    nodes[childIndex] = child
                }
            }
        }
        objectWillChange.send()
    }
    
    public func clearGraph() async {
        logger.infoLog("clearGraph called")  // Updated to infoLog
        nodes = []
        edges = []
        nextNodeLabel = 1
        do {
            try await storage.deleteGraph(name: currentGraphName)  // Updated to multi-graph clear (delete)
            logger.infoLog("clearGraph succeeded")  // Updated to infoLog
        } catch {
            logger.errorLog("clearGraph failed: \(error.localizedDescription)", error: error)  // Updated to errorLog with error
        }
        objectWillChange.send()
    }
    
    // Multi-graph methods (integrated into Storage extension)
    /// Loads the current graph (based on currentGraphName); defaults to empty if not found.
    public func loadGraph() async throws {
        do {
            try await loadFromStorage(for: currentGraphName)
            logger.infoLog("Loaded graph '\(self.currentGraphName)' with \(self.nodes.count) nodes and \(self.edges.count) edges")
            objectWillChange.send()
        } catch GraphStorageError.graphNotFound(_) {
            nodes = []
            edges = []
            logger.warning("Graph '\(self.currentGraphName)' not found; starting empty")  // Use warning for recoverable
        } catch {
            logger.errorLog("Failed to load graph '\(self.currentGraphName)'", error: error)
            nodes = []  // Fallback: Start empty
            throw GraphError.storageFailure(error.localizedDescription)  // Use custom error
        }
    }
    
    /// Saves the current graph state under currentGraphName.
    public func saveGraph() async throws {
        do {
            try await save()
            logger.infoLog("Saved graph '\(self.currentGraphName)'")
        } catch {
            logger.errorLog("Failed to save graph '\(self.currentGraphName)'", error: error)
            throw GraphError.storageFailure(error.localizedDescription)  // Use custom error
        }
    }
    
    /// Creates a new empty graph with the given name and switches to it.
    public func createNewGraph(name: String) async throws {
        try await storage.createNewGraph(name: name)
        currentGraphName = name
        nodes = []
        edges = []
        nextNodeLabel = 1
        undoStack = []
        redoStack = []
        objectWillChange.send()
        logger.infoLog("Created and switched to new graph '\(name)'")  // Updated to infoLog
    }
    
    /// Loads a specific graph by name and switches to it.
    public func loadGraph(name: String) async throws {
        currentGraphName = name
        try await loadGraph()
    }
    
    /// Deletes the graph with the given name (if not current, no change to model).
    public func deleteGraph(name: String) async throws {
        try await storage.deleteGraph(name: name)
        if name == currentGraphName {
            // Reset to default if current is deleted
            currentGraphName = "default"
            try await loadGraph()
        }
        logger.infoLog("Deleted graph '\(name)'")  // Updated to infoLog
    }
    
    /// Lists all available graph names.
    public func listGraphNames() async throws -> [String] {
        try await storage.listGraphNames()
    }
    
    public func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) async throws {
        let viewState = ViewState(offset: offset, zoomScale: zoomScale, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
        try storage.saveViewState(viewState, for: currentGraphName)
    }

    public func loadViewState() async throws -> ViewState? {
        try storage.loadViewState(for: currentGraphName)
    }
}
