// Sources/GraphEditorShared/PersistenceManager.swift

import Foundation
import os.log

private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "storage")

/// Error types for graph storage operations.
public enum GraphStorageError: Error {
    case encodingFailed(Error)
    case writingFailed(Error)
    case loadingFailed(Error)
    case decodingFailed(Error)
    case inconsistentFiles(String)  // New: For cases where one file exists but not the other
}

/// File-based JSON persistence conforming to GraphStorage.
public class PersistenceManager: GraphStorage {
    private let baseURL: URL
    private let nodesFileName = "graphNodes.json"
    private let edgesFileName = "graphEdges.json"
    
    public init(baseURL: URL) {
        self.baseURL = baseURL
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
    
    public convenience init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.init(baseURL: documents.appendingPathComponent("GraphEditor"))
    }
    
    public func save(nodes: [Node], edges: [GraphEdge]) throws {
        let encoder = JSONEncoder()
        do {
            let nodeData = try encoder.encode(nodes)
            let nodeURL = baseURL.appendingPathComponent(nodesFileName)
            try nodeData.write(to: nodeURL)
            
            let edgeData = try encoder.encode(edges)
            let edgeURL = baseURL.appendingPathComponent(edgesFileName)
            try edgeData.write(to: edgeURL)
        } catch let error as EncodingError {
            logger.error("Encoding failed: \(error.localizedDescription)")
            throw GraphStorageError.encodingFailed(error)
        } catch {
            logger.error("Writing failed: \(error.localizedDescription)")
            throw GraphStorageError.writingFailed(error)
        }
    }
    
    public func load() throws -> (nodes: [Node], edges: [GraphEdge]) {
        let fm = FileManager.default
        let nodeURL = baseURL.appendingPathComponent(nodesFileName)
        let edgeURL = baseURL.appendingPathComponent(edgesFileName)
        
        let nodesExist = fm.fileExists(atPath: nodeURL.path)
        let edgesExist = fm.fileExists(atPath: edgeURL.path)
        
        // If both missing, return empty (initial state)
        if !nodesExist && !edgesExist {
            return ([], [])
        }
        
        // If only one exists, throw as inconsistent
        if nodesExist != edgesExist {
            let message = nodesExist ? "Edges file missing but nodes exist" : "Nodes file missing but edges exist"
            logger.error("\(message)")
            throw GraphStorageError.inconsistentFiles(message)
        }
        
        // Both exist: Load and decode
        let decoder = JSONDecoder()
        
        let nodeData: Data
        do {
            nodeData = try Data(contentsOf: nodeURL)
        } catch {
            logger.error("Loading nodes failed: \(error.localizedDescription)")
            throw GraphStorageError.loadingFailed(error)
        }
        let loadedNodes: [Node]
        do {
            loadedNodes = try decoder.decode([Node].self, from: nodeData)
        } catch {
            logger.error("Decoding nodes failed: \(error.localizedDescription)")
            throw GraphStorageError.decodingFailed(error)
        }
        
        let edgeData: Data
        do {
            edgeData = try Data(contentsOf: edgeURL)
        } catch {
            logger.error("Loading edges failed: \(error.localizedDescription)")
            throw GraphStorageError.loadingFailed(error)
        }
        let loadedEdges: [GraphEdge]
        do {
            loadedEdges = try decoder.decode([GraphEdge].self, from: edgeData)
        } catch {
            logger.error("Decoding edges failed: \(error.localizedDescription)")
            throw GraphStorageError.decodingFailed(error)
        }
        
        return (loadedNodes, loadedEdges)
    }
}
