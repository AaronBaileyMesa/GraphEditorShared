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
            let loadedState = try await storage.loadGraphState(for: name)  // Updated: Load full GraphState
            Self.logger.infoLog("loadFromStorage: loaded \(loadedState.nodes.count) nodes, \(loadedState.edges.count) edges for \(name)")  // Fixed: removed .unwrappedNodes (assuming GraphState.nodes is [any NodeProtocol])
            self.nodes = loadedState.nodes.map { AnyNode($0) }
            self.edges = loadedState.edges
            self.hierarchyEdgeColor = loadedState.hierarchyEdgeColor.color
            self.associationEdgeColor = loadedState.associationEdgeColor.color
            self.nextNodeLabel = (nodes.map { $0.unwrapped.label }.max() ?? 0) + 1
        } catch {
            // Fallback to defaults on error
            Self.logger.errorLog("loadFromStorage failed for \(name)", error: error)
            self.nodes = []
            self.edges = []
            self.nextNodeLabel = 1
            throw GraphError.storageFailure(error.localizedDescription)  // Added propagation
        }
        Self.logger.infoLog("loadFromStorage completed for \(name)")
        invalidateHiddenNodesCache()
        await simulator.resetVelocityHistory()
        zeroAllVelocities()
    }
    
    /// Saves the current graph state — **velocities are deliberately stripped**
    public func saveGraph() async throws {
        // Strip velocity from every node before persisting
        let cleanNodes = nodes.map { wrapper -> any NodeProtocol in
            let node = wrapper.unwrapped
            return node.with(position: node.position, velocity: .zero)
        }
        
        let state = GraphState(
            nodes: cleanNodes,
            edges: edges,
            hierarchyEdgeColor: CodableColor(hierarchyEdgeColor),
            associationEdgeColor: CodableColor(associationEdgeColor)
        )
        
        do {
            try await storage.saveGraphState(state, for: currentGraphName)
            Self.logger.infoLog("Saved \(cleanNodes.count) nodes and \(edges.count) edges for '\(currentGraphName)' (velocities stripped)")
        } catch {
            Self.logger.errorLog("Save failed for '\(currentGraphName)'", error: error)
            throw GraphError.storageFailure(error.localizedDescription)
        }
    }
    
    /// Loads the current graph state.
    public func loadGraph() async {
        do {
            try await loadFromStorage(for: currentGraphName)
            await startSimulation()
            Self.logger.infoLog("Loaded graph '\(self.currentGraphName)'")
        } catch {
            Self.logger.errorLog("Load failed for \(self.currentGraphName)", error: error)
            // Handle fallback or error UI in calling code
        }
        invalidateHiddenNodesCache()
        await simulator.resetVelocityHistory()
        zeroAllVelocities()
    }
    
    /// Creates a new empty graph with the given name and switches to it.
    public func createNewGraph(name: String) async throws {
        do {
            try await storage.createNewGraph(name: name)
            currentGraphName = name
            nodes = []
            edges = []
            nextNodeLabel = 1
            await startSimulation()
            Self.logger.infoLog("Created new graph '\(name)'")
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
