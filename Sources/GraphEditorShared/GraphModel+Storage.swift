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
    private static let logger = Logger.forCategory("graphmodel-storage")  // ADDED: Define local static logger for this extension

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

    private func loadFromStorage(for name: String) async throws {
        Self.logger.infoLog("loadFromStorage started for \(name)")
        do {
            let (loadedNodes, loadedEdges) = try await storage.load(for: name)
            Self.logger.infoLog("loadFromStorage: loaded \(loadedNodes.count) nodes, \(loadedEdges.count) edges for \(name)")
            self.nodes = loadedNodes.map { AnyNode($0) }
            self.edges = loadedEdges
            self.nextNodeLabel = (nodes.map { $0.unwrapped.label }.max() ?? 0) + 1
        } catch {
            Self.logger.errorLog("loadFromStorage failed for \(name)", error: error)
            throw GraphError.storageFailure(error.localizedDescription)  // Added propagation with custom error
        }
    }
    
    public func load() async {
        Self.logger.infoLog("GraphModel.load() called")
        do {
            try await loadFromStorage(for: currentGraphName)
            syncCollapsedPositions()
            if let viewState = try storage.loadViewState(for: currentGraphName) {
                Self.logger.infoLog("Loaded view state: offset \(viewState.offset), zoom \(viewState.zoomScale)")
            }
            Self.logger.infoLog("GraphModel.load() succeeded; nodes: \(nodes.count), edges: \(edges.count)")
        } catch {
            Self.logger.errorLog("GraphModel.load() failed: \(error.localizedDescription)", error: error)
        }
    }
    
    public func save() async throws {
        Self.logger.infoLog("GraphModel.save() called; nodes: \(nodes.count), edges: \(edges.count)")
        do {
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges, for: currentGraphName)
            Self.logger.infoLog("GraphModel.save() succeeded")
        } catch {
            Self.logger.errorLog("GraphModel.save() failed: \(error.localizedDescription)", error: error)
            throw GraphError.storageFailure(error.localizedDescription)  // Added propagation
        }
    }

    public func clearGraph() async {
        Self.logger.infoLog("clearGraph called")
        nodes = []
        edges = []
        nextNodeLabel = 1
        do {
            try await storage.deleteGraph(name: currentGraphName)
            Self.logger.infoLog("clearGraph succeeded")
        } catch {
            Self.logger.errorLog("clearGraph failed: \(error.localizedDescription)", error: error)
        }
        objectWillChange.send()
    }
    
    // Multi-graph methods (integrated into Storage extension)
    /// Loads the current graph (based on currentGraphName); defaults to empty if not found.
    public func loadGraph() async {
        do {
            try await loadFromStorage(for: currentGraphName)
            nextNodeLabel = (nodes.map { $0.label }.max() ?? 0) + 1
            Self.logger.infoLog("Loaded graph '\(self.currentGraphName)' with \(self.nodes.count) nodes and \(self.edges.count) edges")
            objectWillChange.send()
        } catch GraphStorageError.graphNotFound(_) {
            nodes = []
            edges = []
            nextNodeLabel = 1
            Self.logger.warning("Graph '\(self.currentGraphName)' not found; starting empty")
        } catch {
            nodes = []
            edges = []
            nextNodeLabel = 1
            Self.logger.errorLog("Failed to load graph '\(self.currentGraphName)'", error: error)
        }
    }
    
    /// Saves the current graph state under currentGraphName.
    public func saveGraph() async throws {
        do {
            try await save()
            Self.logger.infoLog("Saved graph '\(self.currentGraphName)'")
        } catch {
            Self.logger.errorLog("Failed to save graph '\(self.currentGraphName)'", error: error)
            throw GraphError.storageFailure(error.localizedDescription)
        }
    }
    
    /// Creates a new empty graph with the given name and switches to it.
    public func createNewGraph(name: String) async throws {
        do {
            try await storage.createNewGraph(name: name)
            currentGraphName = name
            nodes = []
            edges = []
            nextNodeLabel = 1
            undoStack = []
            redoStack = []
            objectWillChange.send()
            Self.logger.infoLog("Created and switched to new graph '\(name)'")
        } catch {
            Self.logger.errorLog("Failed to create graph '\(name)'", error: error)
            throw GraphError.storageFailure(error.localizedDescription)  // Added propagation
        }
    }
    
    /// Loads a specific graph by name and switches to it.
    public func loadGraph(name: String) async {
        currentGraphName = name
        await loadGraph()
    }
    
    /// Deletes the graph with the given name (if not current, no change to model).
    public func deleteGraph(name: String) async throws {
        do {
            try await storage.deleteGraph(name: name)
            if name == currentGraphName {
                currentGraphName = "default"
                await loadGraph()
            }
            Self.logger.infoLog("Deleted graph '\(name)'")
        } catch {
            Self.logger.errorLog("Failed to delete graph '\(name)'", error: error)
            throw GraphError.storageFailure(error.localizedDescription)  // Added propagation
        }
    }
    
    /// Lists all available graph names.
    public func listGraphNames() async throws -> [String] {
        do {
            return try await storage.listGraphNames()
        } catch {
            Self.logger.errorLog("Failed to list graph names", error: error)
            throw GraphError.storageFailure(error.localizedDescription)  // Added propagation
        }
    }
    
    public func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) async throws {
        let viewState = ViewState(offset: offset, zoomScale: zoomScale, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
        do {
            try storage.saveViewState(viewState, for: currentGraphName)
        } catch {
            Self.logger.errorLog("Failed to save view state for '\(currentGraphName)'", error: error)
            throw GraphError.storageFailure(error.localizedDescription)  // Added propagation
        }
    }

    public func loadViewState() async throws -> ViewState? {
        do {
            return try storage.loadViewState(for: currentGraphName)
        } catch {
            Self.logger.errorLog("Failed to load view state for '\(currentGraphName)'", error: error)
            throw GraphError.storageFailure(error.localizedDescription)  // Added propagation
        }
    }
}
