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
    case inconsistentFiles(String)  // Retained for potential future multi-file use
}

/// File-based JSON persistence conforming to GraphStorage.
@available(iOS 13.0, watchOS 6.0, *)
public class PersistenceManager: GraphStorage {
    private let fileName = "graphState.json"
    private let fileURL: URL
    
    public init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent(fileName)
    }
    
    struct SavedState: Codable {
        var version: Int = 1  // Change let to var
        let nodes: [NodeWrapper]
        let edges: [GraphEdge]
        let viewState: ViewState?  // Embed view state (optional)
    }
    
    public func save(nodes: [any NodeProtocol], edges: [GraphEdge]) throws {
        let wrapped = nodes.map { node in
            if let n = node as? Node {
                return NodeWrapper.node(n)
            } else if let tn = node as? ToggleNode {
                return NodeWrapper.toggleNode(tn)
            } else {
                os_log("Unsupported node type: %{public}s", log: logger, type: .error, String(describing: type(of: node)))
                fatalError("Unsupported node type: \(type(of: node))")
            }
        }
        let state = SavedState(nodes: wrapped, edges: edges, viewState: nil)  // Populate viewState if needed from params
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL)
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
        guard fm.fileExists(atPath: fileURL.path) else { return ([], []) }
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try JSONDecoder().decode(SavedState.self, from: data)
            if state.version != 1 {
                throw GraphStorageError.decodingFailed(NSError(domain: "Invalid version \(state.version)", code: 0))
            }
            let loadedNodes = state.nodes.map { $0.value }
            return (loadedNodes, state.edges)
        } catch let error as DecodingError {
            os_log("Decoding failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            throw GraphStorageError.decodingFailed(error)
        } catch {
            os_log("Loading failed: %{public}s", log: logger, type: .error, error.localizedDescription)
            throw GraphStorageError.loadingFailed(error)
        }
    }
    
    public func clear() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            try fm.removeItem(at: fileURL)
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
        UserDefaults.standard.synchronize()  // Ensure immediate write
    }

    // Updated load method
    public func loadViewState() throws -> (offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?)? {
        guard let data = UserDefaults.standard.data(forKey: "graphViewState") else { return nil }
        let state = try JSONDecoder().decode(ViewState.self, from: data)
        return (offset: state.offset, zoomScale: state.zoomScale, selectedNodeID: state.selectedNodeID, selectedEdgeID: state.selectedEdgeID)
    }
}
