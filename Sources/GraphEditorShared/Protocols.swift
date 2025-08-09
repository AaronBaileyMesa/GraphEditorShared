//
//  GraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//


@available(iOS 13.0, *)
public protocol GraphStorage {
    /// Saves the graph nodes and edges, throwing on failure (e.g., encoding or writing errors).
    func save(nodes: [Node], edges: [GraphEdge]) throws
    /// Loads the graph nodes and edges, throwing on failure (e.g., file not found or decoding errors).
    func load() throws -> (nodes: [Node], edges: [GraphEdge])
    func clear() throws  // New: For resetting storage
}
