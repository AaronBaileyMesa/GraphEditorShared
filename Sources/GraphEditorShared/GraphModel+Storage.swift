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
            Self.storageLogger.infoLog("loadFromStorage started for \(name)")
            do {
                let loadedState = try await storage.loadGraphState(for: name)
                Self.storageLogger.infoLog("loadFromStorage: loaded \(loadedState.nodes.count) nodes, \(loadedState.edges.count) edges for \(name)")
                
                self.nodes = loadedState.nodes
                self.edges = loadedState.edges
                self.hierarchyEdgeColor = loadedState.hierarchyEdgeColor.color
                self.associationEdgeColor = loadedState.associationEdgeColor.color
                self.uiConfig = loadedState.uiConfig
                self.globalUiConfig = loadedState.globalUiConfig
                self.nextNodeLabel = (nodes.map { $0.unwrapped.label }.max() ?? 0) + 1
                
                self.isSimulating = loadedState.isSimulating
                if self.isSimulating {
                    await startSimulation()
                }
            } catch let storageError as GraphStorageError {
                if case .graphNotFound(_) = storageError {
                    Self.storageLogger.warning("Graph '\(name)' not found")
                    if name != "default" {
                        Self.storageLogger.infoLog("Falling back to default graph")
                        currentGraphName = "default"
                        do {
                            let loadedState = try await storage.loadGraphState(for: "default")
                            Self.storageLogger.infoLog("loadFromStorage: loaded \(loadedState.nodes.count) nodes, \(loadedState.edges.count) edges for default")
                            
                            self.nodes = loadedState.nodes
                            self.edges = loadedState.edges
                            self.hierarchyEdgeColor = loadedState.hierarchyEdgeColor.color
                            self.associationEdgeColor = loadedState.associationEdgeColor.color
                            self.uiConfig = loadedState.uiConfig
                            self.globalUiConfig = loadedState.globalUiConfig
                            self.nextNodeLabel = (nodes.map { $0.unwrapped.label }.max() ?? 0) + 1
                            
                            self.isSimulating = loadedState.isSimulating
                            if self.isSimulating {
                                await startSimulation()
                            }
                        } catch let defaultError as GraphStorageError {
                            if case .graphNotFound(_) = defaultError {
                                Self.storageLogger.warning("Default graph not found – initializing")
                                await initializeDefaultGraph()
                                try? await saveGraph()
                            } else {
                                Self.storageLogger.errorLog("loadFromStorage failed for default", error: defaultError)
                                nodes = []
                                edges = []
                                nextNodeLabel = 1
                                self.isSimulating = false
                                throw GraphError.storageFailure(defaultError.localizedDescription)
                            }
                        } catch {
                            Self.storageLogger.errorLog("loadFromStorage failed for default", error: error)
                            nodes = []
                            edges = []
                            nextNodeLabel = 1
                            self.isSimulating = false
                            throw GraphError.storageFailure(error.localizedDescription)
                        }
                    } else {
                        Self.storageLogger.warning("Default graph not found – initializing")
                        await initializeDefaultGraph()
                        try? await saveGraph()
                    }
                } else {
                    Self.storageLogger.errorLog("loadFromStorage failed for \(name)", error: storageError)
                    nodes = []
                    edges = []
                    nextNodeLabel = 1
                    self.isSimulating = false
                    throw GraphError.storageFailure(storageError.localizedDescription)
                }
            } catch {
                Self.storageLogger.errorLog("loadFromStorage failed for \(name)", error: error)
                nodes = []
                edges = []
                nextNodeLabel = 1
                self.isSimulating = false
                throw GraphError.storageFailure(error.localizedDescription)
            }
        }
        
        @MainActor
        public func initializeDefaultGraph() async {
            // Reset basics
            nodes = []
            edges = []
            nextNodeLabel = 1
            hierarchyEdgeColor = .blue
            associationEdgeColor = .white
            uiConfig = [:]
            globalUiConfig = []
            self.isSimulating = false  // Added to ensure consistent default
            
            // Add default nodes and edge
            let node1 = await addNode(at: CGPoint(x: 0, y: 0))
            let node2 = await addNode(at: CGPoint(x: 100, y: 0))
            await addEdge(from: node1.id, target: node2.id, type: .association)
            
            nextNodeLabel = 3
            
            invalidateHiddenNodesCache()
            objectWillChange.send()
            
            Self.storageLogger.infoLog("Initialized default graph with 2 nodes and 1 edge")
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
                globalUiConfig: globalUiConfig,
                isSimulating: isSimulating  // NEW: Save simulation state
            )
            try await storage.saveGraphState(state, for: currentGraphName)
            Self.logger.infoLog("Saved \(self.nodes.count) nodes and \(self.edges.count) edges for '\(currentGraphName)'")
        } catch {
            Self.logger.errorLog("saveGraph failed for \(currentGraphName)", error: error)
            throw GraphError.storageFailure(error.localizedDescription)
        }
    }
    
    public func loadGraph() async throws {
        try await loadFromStorage(for: currentGraphName)
        invalidateHiddenNodesCache()
        objectWillChange.send()
    }
    
    public func deleteGraph(named name: String) async throws {
        do {
            try await storage.deleteGraph(name: name)
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
        try await loadGraph()
    }
    
    @MainActor
    public func initializeDefaultGraph() {
        nodes = []
        edges = []
        nextNodeLabel = 1
        hierarchyEdgeColor = .blue
        associationEdgeColor = .white
        uiConfig = [:]
        globalUiConfig = []
        isSimulating = false
        objectWillChange.send()
        invalidateHiddenNodesCache()  // If this exists; otherwise remove
        Self.storageLogger.infoLog("Initialized default empty graph")
    }
}
