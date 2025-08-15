// Sources/GraphEditorShared/PersistenceManager.swift

import Foundation
import os.log

private let logger = OSLog(subsystem: "io.handcart.GraphEditor", category: "storage")

@available(iOS 13.0, watchOS 6.0, *)
/// Error types for graph storage operations.
public enum GraphStorageError: Error {
    case encodingFailed(Error)
    case writingFailed(Error)
    case loadingFailed(Error)
    case decodingFailed(Error)
    case inconsistentFiles(String)  // New: For cases where one file exists but not the other
}

/// File-based JSON persistence conforming to GraphStorage.
@available(iOS 13.0, watchOS 6.0, *)
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
    
    public func save(nodes: [any NodeProtocol], edges: [GraphEdge]) throws {
        let wrappedNodes = nodes.map { node in
            if let n = node as? Node {
                return NodeWrapper.node(n)
            } else if let tn = node as? ToggleNode {
                return NodeWrapper.toggleNode(tn)
            } else {
                fatalError("Unsupported node type: \(type(of: node))")
            }
        }
        let encoder = JSONEncoder()
        do {
            let nodeData = try encoder.encode(wrappedNodes)
            let nodeURL = baseURL.appendingPathComponent(nodesFileName)
            try nodeData.write(to: nodeURL)
            
            let edgeData = try encoder.encode(edges)
            let edgeURL = baseURL.appendingPathComponent(edgesFileName)
            try edgeData.write(to: edgeURL)
        } catch let error as EncodingError {
            os_log("Encoding failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            throw GraphStorageError.encodingFailed(error)
        } catch {
            os_log("Writing failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            throw GraphStorageError.writingFailed(error)
        }
    }

    public func load() throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        let fm = FileManager.default
        let nodeURL = baseURL.appendingPathComponent(nodesFileName)
        let edgeURL = baseURL.appendingPathComponent(edgesFileName)
        
        let nodesExist = fm.fileExists(atPath: nodeURL.path)
        let edgesExist = fm.fileExists(atPath: edgeURL.path)
        
        if !nodesExist && !edgesExist {
            return ([], [])
        }
        
        // Handle inconsistency: Delete orphan and return empty
        if nodesExist != edgesExist {
            let message = nodesExist ? "Edges file missing but nodes exist; deleting orphan nodes file" : "Nodes file missing but edges exist; deleting orphan edges file"
            os_log("%{public}s", log: logger, type: .error, message)
            if nodesExist {
                try? fm.removeItem(at: nodeURL)
            } else {
                try? fm.removeItem(at: edgeURL)
            }
            return ([], [])  // Graceful empty return
        }
        
        // Both exist: Load and decode
        let decoder = JSONDecoder()
        
        let nodeData: Data
        do {
            nodeData = try Data(contentsOf: nodeURL)
        } catch {
            os_log("Loading nodes failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            throw GraphStorageError.loadingFailed(error)
        }
        let loadedWrapped: [NodeWrapper]
        do {
            loadedWrapped = try decoder.decode([NodeWrapper].self, from: nodeData)
        } catch {
            os_log("Decoding nodes failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            throw GraphStorageError.decodingFailed(error)
        }
        let loadedNodes = loadedWrapped.map { $0.value }
        
        let edgeData: Data
        do {
            edgeData = try Data(contentsOf: edgeURL)
        } catch {
            os_log("Loading edges failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            throw GraphStorageError.loadingFailed(error)
        }
        let loadedEdges: [GraphEdge]
        do {
            loadedEdges = try decoder.decode([GraphEdge].self, from: edgeData)
        } catch {
            os_log("Decoding edges failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            throw GraphStorageError.decodingFailed(error)
        }
        
        return (loadedNodes, loadedEdges)
    }
    public func clear() throws {
        let fm = FileManager.default
        let nodeURL = baseURL.appendingPathComponent(nodesFileName)
        let edgeURL = baseURL.appendingPathComponent(edgesFileName)
        
        if fm.fileExists(atPath: nodeURL.path) {
            try fm.removeItem(at: nodeURL)
        }
        if fm.fileExists(atPath: edgeURL.path) {
            try fm.removeItem(at: edgeURL)
        }
    }

    // Updated helper struct
    struct ViewState: Codable {
        let offset: CGPoint
        let zoomScale: CGFloat
        let selectedNodeID: UUID?  // NodeID is UUID from GraphTypes.swift
        let selectedEdgeID: UUID?  // Matches @Published in GraphViewModel
    }

    // Updated save method
    public func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) throws {
        let state = ViewState(offset: offset, zoomScale: zoomScale, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
        let data = try JSONEncoder().encode(state)
        UserDefaults.standard.set(data, forKey: "graphViewState")
        // In saveViewState()
        UserDefaults.standard.set(data, forKey: "graphViewState")
        UserDefaults.standard.synchronize()  // Add this
    }

    // Updated load method
    public func loadViewState() throws -> (offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?)? {
        guard let data = UserDefaults.standard.data(forKey: "graphViewState") else { return nil }
        let state = try JSONDecoder().decode(ViewState.self, from: data)
        return (offset: state.offset, zoomScale: state.zoomScale, selectedNodeID: state.selectedNodeID, selectedEdgeID: state.selectedEdgeID)
    }
}
