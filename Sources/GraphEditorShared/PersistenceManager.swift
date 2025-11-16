//
//  PersistenceManager.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
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
    
    // MARK: - Default (Single-Graph) Methods
    
    public func clear() async throws {
        try await deleteGraph(name: defaultGraphName)
    }
    
    // MARK: - Multi-Graph Methods
    
    public func listGraphNames() async throws -> [String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            let names = contents
                .filter { $0.lastPathComponent.hasPrefix("graph-") && $0.pathExtension == "json" }
                .map { $0.lastPathComponent.replacingOccurrences(of: "graph-", with: "").replacingOccurrences(of: ".json", with: "") }
            logger.debug("Listed graphs: \(names)")
            return names.sorted()
        } catch {
            logger.error("Failed to list graphs: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func createNewGraph(name: String) async throws {
        if FileManager.default.fileExists(atPath: fileURL(for: name).path) {
            throw GraphStorageError.graphExists(name)
        }
        // No need to create empty file; save will handle
        logger.debug("Created new graph '\(name)' (empty)")
    }
    
    // MARK: - GraphState Persistence (Per-Graph)
    
    public func saveGraphState(_ graphState: GraphState, for name: String) async throws {
        do {
            let data = try JSONEncoder().encode(graphState)
            let url = fileURL(for: name)
            try data.write(to: url, options: .atomic)
            logger.debug("Saved \(graphState.nodes.count) nodes and \(graphState.edges.count) edges for graph '\(name)'")
        } catch let error as EncodingError {
            logger.error("Encoding failed for '\(name)': \(error.localizedDescription)")
            throw GraphStorageError.encodingFailed(error)
        } catch {
            logger.error("Writing failed for '\(name)': \(error.localizedDescription)")
            throw GraphStorageError.writingFailed(error)
        }
    }
    
    public func loadGraphState(for name: String) async throws -> GraphState {
        let url = fileURL(for: name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            logger.debug("No saved file for '\(name)'; throwing not found")
            throw GraphStorageError.graphNotFound(name)
        }
        do {
            let data = try Data(contentsOf: url)
            let state = try JSONDecoder().decode(GraphState.self, from: data)
            logger.debug("Loaded \(state.nodes.count) nodes and \(state.edges.count) edges for graph '\(name)'")
            return state
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
