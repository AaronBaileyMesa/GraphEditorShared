//
//  GraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//


// Sources/GraphEditorShared/Protocols.swift

@available(iOS 13.0, watchOS 6.0, *)
public protocol GraphStorage {
    /// Saves the graph nodes and edges, throwing on failure (e.g., encoding or writing errors).
    func save(nodes: [any NodeProtocol], edges: [GraphEdge]) throws
    /// Loads the graph nodes and edges, throwing on failure (e.g., file not found or decoding errors).
    func load() throws -> (nodes: [any NodeProtocol], edges: [GraphEdge])
    func clear() throws  // Unchanged
}
