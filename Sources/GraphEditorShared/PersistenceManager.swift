// Sources/GraphEditorShared/PersistenceManager.swift

import Foundation
import os  // For Logger

@available(iOS 16.0, watchOS 6.0, *)
private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "storage")

/// Error types for graph storage operations.
public enum GraphStorageError: Error {
    case encodingFailed(Error)
    case writingFailed(Error)
    case loadingFailed(Error)
    case decodingFailed(Error)
    case inconsistentFiles(String)  // Retained for potential future multi-file use
    case graphExists(String)  // New: For createNewGraph duplicates
    case graphNotFound(String)  // New: For load/delete misses
}

/// File-based JSON persistence conforming to GraphStorage.
@available(iOS 16.0, watchOS 6.0, *)
public class PersistenceManager: GraphStorage {
    private let directory: URL
    private let defaultGraphName = "default"
    
    public init(directoryName: String = "graphs") {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directory = documents.appendingPathComponent(directoryName)
        createDirectoryIfNeeded()
    }
    
    private func createDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create directory: \(error.localizedDescription)")
        }
    }
    
    private func fileURL(for name: String) -> URL {
        directory.appendingPathComponent("graph-\(name).json")
    }
    
    private func viewStateKey(for name: String) -> String {
        "graphViewState_\(name)"
    }
    
    struct SavedState: Codable {
        var version: Int = 1
        let nodes: [NodeWrapper]
        let edges: [GraphEdge]
    }
    
    // MARK: - Default (Single-Graph) Methods (Unchanged Behavior)
    
    public func save(nodes: [any NodeProtocol], edges: [GraphEdge]) async throws {
        try await save(nodes: nodes, edges: edges, for: defaultGraphName)
    }
    
    public func load() async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        try await load(for: defaultGraphName)
    }
    
    public func clear() async throws {
        try await deleteGraph(name: defaultGraphName)
    }
    
    public func saveViewState(_ viewState: ViewState) async throws {
        try saveViewState(viewState, for: defaultGraphName)
    }
    
    public func loadViewState() async throws -> ViewState? {
        try loadViewState(for: defaultGraphName)
    }
    
    // MARK: - Multi-Graph Methods
    
    public func listGraphNames() async throws -> [String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            let names = contents
                .filter { $0.lastPathComponent.hasPrefix("graph-") && $0.pathExtension == "json" }
                .map { String($0.deletingPathExtension().lastPathComponent.dropFirst(6)) }  // Drop "graph-"
                .sorted()
            logger.debug("Listed \(names.count) graphs: \(names)")
            return names
        } catch {
            logger.error("Listing failed: \(error.localizedDescription)")
            throw GraphStorageError.loadingFailed(error)
        }
    }
    
    public func createNewGraph(name: String) async throws {
        let url = fileURL(for: name)
        if FileManager.default.fileExists(atPath: url.path) {
            logger.warning("Graph '\(name)' already exists")
            throw GraphStorageError.graphExists(name)
        }
        // Create empty graph
        let emptyNodes: [any NodeProtocol] = []
        let emptyEdges: [GraphEdge] = []
        try await save(nodes: emptyNodes, edges: emptyEdges, for: name)
        logger.debug("Created new graph: \(name)")
    }
    
    public func save(nodes: [any NodeProtocol], edges: [GraphEdge], for name: String) async throws {
        let wrapped = nodes.compactMap { node -> NodeWrapper? in
            if let plainNode = node as? Node { return .node(plainNode) } else if let toggleNode = node as? ToggleNode { return .toggleNode(toggleNode) } else {
                logger.error("Unsupported node type: \(String(describing: type(of: node))); skipping.")
                return nil  // Skip instead of fatalError
            }
        }
        let state = SavedState(nodes: wrapped, edges: edges)
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL(for: name), options: .atomic)  // Ensures full overwrite
            logger.debug("Saved \(wrapped.count) nodes and \(edges.count) edges for graph '\(name)'")
        } catch let error as EncodingError {
            logger.error("Encoding failed for '\(name)': \(error.localizedDescription)")
            throw GraphStorageError.encodingFailed(error)
        } catch {
            logger.error("Writing failed for '\(name)': \(error.localizedDescription)")
            throw GraphStorageError.writingFailed(error)
        }
    }
    
    public func load(for name: String) async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        let url = fileURL(for: name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.debug("No saved file for '\(name)'; throwing not found")
            throw GraphStorageError.graphNotFound(name)
        }
        do {
            let data = try Data(contentsOf: url)
            let state = try JSONDecoder().decode(SavedState.self, from: data)
            if state.version != 1 {
                throw GraphStorageError.decodingFailed(NSError(domain: "Invalid version \(state.version) for '\(name)'", code: 0))
            }
            let loadedNodes = state.nodes.map { $0.value }
            logger.debug("Loaded \(loadedNodes.count) nodes and \(state.edges.count) edges for graph '\(name)'")
            return (loadedNodes, state.edges)
        } catch let error as DecodingError {
            logger.error("Decoding failed for '\(name)': \(error.localizedDescription)")
            throw GraphStorageError.decodingFailed(error)
        } catch {
            logger.error("Loading failed for '\(name)': \(error.localizedDescription)")
            throw GraphStorageError.loadingFailed(error)
        }
    }
    
    public func deleteGraph(name: String) async throws {
        let url = fileURL(for: name)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
            // Also clear associated view state
            UserDefaults.standard.removeObject(forKey: viewStateKey(for: name))
            UserDefaults.standard.synchronize()
            logger.debug("Deleted graph '\(name)'")
        } else {
            logger.warning("Graph '\(name)' not found for deletion")
            throw GraphStorageError.graphNotFound(name)
        }
    }
    
    // MARK: - View State (Per-Graph)
    
    public func saveViewState(_ viewState: ViewState, for name: String) throws {
        let data = try JSONEncoder().encode(viewState)
        UserDefaults.standard.set(data, forKey: viewStateKey(for: name))
        UserDefaults.standard.synchronize()  // Ensure immediate write
        logger.debug("Saved view state for '\(name)'")
    }
    
    public func loadViewState(for name: String) throws -> ViewState? {
        guard let data = UserDefaults.standard.data(forKey: viewStateKey(for: name)) else {
            logger.debug("No view state for '\(name)'")
            return nil
        }
        let decoded = try JSONDecoder().decode(ViewState.self, from: data)
        logger.debug("Loaded view state for '\(name)'")
        return decoded
    }
}
