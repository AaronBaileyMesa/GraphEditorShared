//
//  GraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//

import SwiftUI
// Sources/GraphEditorShared/Protocols.swift

@available(iOS 13.0, watchOS 6.0, *)
public protocol GraphStorage {
    /// Saves the graph nodes and edges, throwing on failure (e.g., encoding or writing errors).
    func save(nodes: [any NodeProtocol], edges: [GraphEdge]) async throws
    /// Loads the graph nodes and edges, throwing on failure (e.g., file not found or decoding errors).
    func load() async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge])
    func clear() async throws  // Unchanged
    func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) async throws
    func loadViewState() async throws -> (offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?)?
}

// In GraphEditorShared/Sources/GraphEditorShared/Protocols.swift (add inside protocol GraphStorage)



// Add a protocol extension for defaults (at bottom of file)
extension GraphStorage {
    func saveViewState(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?) throws {
        // Default: Do nothing (for storages that don't support view state)
    }
    
    func loadViewState() throws -> (offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID?, selectedEdgeID: UUID?)? {
        return nil  // Default: No state
    }
}
