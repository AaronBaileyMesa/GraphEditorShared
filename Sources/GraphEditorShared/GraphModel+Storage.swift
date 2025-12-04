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
    fileprivate static let storageLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "GraphEditorShared", category: "storage")
    
    func syncCollapsedPositions() {
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
            let loadedState = try await storage.loadGraphState(for: name)
            Self.logger.infoLog("loadFromStorage: loaded \(loadedState.nodes.count) nodes, \(loadedState.edges.count) edges for \(name)")
            
            self.nodes = loadedState.nodes  // ← Direct assignment ([AnyNode])
            self.edges = loadedState.edges
            self.hierarchyEdgeColor = loadedState.hierarchyEdgeColor.color
            self.associationEdgeColor = loadedState.associationEdgeColor.color
            self.uiConfig = loadedState.uiConfig
            self.globalUiConfig = loadedState.globalUiConfig
            self.nextNodeLabel = (nodes.map { $0.unwrapped.label }.max() ?? 0) + 1
        } catch {
                Self.logger.errorLog("loadFromStorage failed for \(name)", error: error)
                nodes = []  // Reset to empty on failure
                edges = []
                nextNodeLabel = 1
                throw GraphError.storageFailure(error.localizedDescription)
            }
    }
    
    public func saveGraph() async throws {
        Self.logger.infoLog("saveGraph started for \(currentGraphName)")
        do {
            let state = GraphState(
                nodes: nodes,  // ← CHANGED: Direct [AnyNode], no .map { $0.unwrapped }
                edges: edges,
                hierarchyEdgeColor: CodableColor(hierarchyEdgeColor),
                associationEdgeColor: CodableColor(associationEdgeColor),
                uiConfig: uiConfig,
                globalUiConfig: globalUiConfig
            )
            try await storage.saveGraphState(state, for: currentGraphName)
            Self.logger.infoLog("saveGraph completed for \(currentGraphName)")
        } catch {
            Self.logger.errorLog("saveGraph failed for \(currentGraphName)", error: error)
            throw GraphError.storageFailure(error.localizedDescription)  // Added propagation
        }
    }
    
    /// Loads the current graph (based on currentGraphName).
    public func loadGraph() async {
        do {
            try await loadFromStorage(for: currentGraphName)
        } catch {
            Self.logger.errorLog("loadGraph failed for \(currentGraphName)", error: error)
            // Handle fallback, e.g., create default graph
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
                nodes = []  // Explicitly clear
                edges = []
                nextNodeLabel = 1
                invalidateHiddenNodesCache()
                objectWillChange.send()
                await loadGraph()  // Reload default
            }
            Self.logger.infoLog("Deleted graph '\(name)'")
        } catch {
            Self.logger.errorLog("Failed to delete graph '\(name)'", error: error)
            throw GraphError.storageFailure(error.localizedDescription)
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
    
    public func saveViewState(
        offset: CGSize,                    // ← CGSize, not CGPoint
        zoomScale: CGFloat,
        selectedNodeID: UUID?,
        selectedEdgeID: UUID?
    ) async throws {
        let viewState = ViewState(
            offset: offset,                // ← now matches perfectly
            zoomScale: zoomScale,
            selectedNodeID: selectedNodeID,
            selectedEdgeID: selectedEdgeID
        )
        do {
            try storage.saveViewState(viewState, for: currentGraphName)
        } catch {
            Self.logger.errorLog("Failed to save view state for '\(currentGraphName)'", error: error)
            throw GraphError.storageFailure(error.localizedDescription)
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
    
    public func createNewGraph(name: String) async throws {
        // 1. Validate name
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw GraphError.invalidState("Graph name cannot be empty")
        }
        
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // 2. Check if already exists
        let existingNames = try await storage.listGraphNames()
        if existingNames.contains(trimmedName) {
            throw GraphStorageError.graphExists(trimmedName)
        }
        
        // 3. Create empty graph file (PersistenceManager.createNewGraph just checks existence)
        try await storage.createNewGraph(name: trimmedName)
        
        // 4. Switch to the new (empty) graph
        currentGraphName = trimmedName
        
        // 5. Clear current model state
        nodes = []
        edges = []
        nextNodeLabel = 1
        hierarchyEdgeColor = .blue
        associationEdgeColor = .white
        
        // 6. Clear undo/redo
        undoStack.removeAll()
        redoStack.removeAll()
        
        // 7. Save empty state (optional but recommended for consistency)
        try await saveGraph()
        
        // 8. Invalidate caches and notify
        invalidateHiddenNodesCache()
        objectWillChange.send()
        
        Self.logger.infoLog("Created and switched to new empty graph: '\(trimmedName)'")
    }
    
    public func switchToGraph(named name: String) async throws {
        nodes = []  // Clear before load
            edges = []
            currentGraphName = name
            await loadGraph()
    }
    
}
