// Sources/GraphEditorShared/PersistenceManager.swift

import Foundation
import os  // For Logger

private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "storage")

@available(iOS 14.0, watchOS 6.0, *)
/// Error types for graph storage operations.
public enum GraphStorageError: Error {
    case encodingFailed(Error)
    case writingFailed(Error)
    case loadingFailed(Error)
    case decodingFailed(Error)
    case inconsistentFiles(String)  // Retained for potential future multi-file use
}

/// File-based JSON persistence conforming to GraphStorage.
@available(iOS 14.0, watchOS 6.0, *)
public class PersistenceManager: GraphStorage {
    private let fileName = "graphState.json"
    private let fileURL: URL
    
    public init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent(fileName)
    }
    
    struct SavedState: Codable {
        var version: Int = 1
        let nodes: [NodeWrapper]
        let edges: [GraphEdge]
        let viewState: ViewState?  // Embed view state (optional)
    }
    
    public func save(nodes: [any NodeProtocol], edges: [GraphEdge]) async throws {
        let wrapped = nodes.compactMap { node -> NodeWrapper? in
            if let plainNode = node as? Node { return .node(plainNode) } else if let toggleNode = node as? ToggleNode { return .toggleNode(toggleNode) } else {
                logger.error("Unsupported node type: \(String(describing: type(of: node))); skipping.")
                return nil  // Skip instead of fatalError
            }
        }
        let state = SavedState(nodes: wrapped, edges: edges, viewState: nil)  // Add viewState if passed
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL)
            logger.debug("Saved \(wrapped.count) nodes and \(edges.count) edges")
        } catch let error as EncodingError {
            logger.error("Encoding failed: \(error.localizedDescription)")
            throw GraphStorageError.encodingFailed(error)
        } catch {
            logger.error("Writing failed: \(error.localizedDescription)")
            throw GraphStorageError.writingFailed(error)
        }
    }
    
    public func load() async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            logger.debug("No saved file; returning empty")
            return ([], [])
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try JSONDecoder().decode(SavedState.self, from: data)
            if state.version != 1 {
                throw GraphStorageError.decodingFailed(NSError(domain: "Invalid version \(state.version)", code: 0))
            }
            let loadedNodes = state.nodes.map { $0.value }
            logger.debug("Loaded \(loadedNodes.count) nodes and \(state.edges.count) edges")
            return (loadedNodes, state.edges)
        } catch let error as DecodingError {
            logger.error("Decoding failed: \(error.localizedDescription)")
            throw GraphStorageError.decodingFailed(error)
        } catch {
            logger.error("Loading failed: \(error.localizedDescription)")
            throw GraphStorageError.loadingFailed(error)
        }
    }

    public func clear() async throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            logger.debug("Cleared saved graph")
        }
    }
    
    public func saveViewState(_ viewState: ViewState) async throws {
        let data = try JSONEncoder().encode(viewState)
        UserDefaults.standard.set(data, forKey: "graphViewState")
        UserDefaults.standard.synchronize()  // Ensure immediate write
    }

    public func loadViewState() async throws -> ViewState? {
        guard let data = UserDefaults.standard.data(forKey: "graphViewState") else { return nil }
        return try JSONDecoder().decode(ViewState.self, from: data)
    }
}
