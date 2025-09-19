//
//  GraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//

// Sources/GraphEditorShared/Protocols.swift

import SwiftUI

@available(iOS 16.0, watchOS 6.0, *)
public struct ViewState: Codable {
    public var offset: CGPoint
    public var zoomScale: CGFloat
    public var selectedNodeID: UUID?
    public var selectedEdgeID: UUID?
}

@available(iOS 16.0, watchOS 6.0, *)
public protocol GraphStorage {
    /// Saves the graph nodes and edges, throwing on failure (e.g., encoding or writing errors).
    func save(nodes: [any NodeProtocol], edges: [GraphEdge]) async throws
    /// Loads the graph nodes and edges, throwing on failure (e.g., file not found or decoding errors).
    func load() async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge])
    func clear() async throws  // Unchanged
    func saveViewState(_ viewState: ViewState) async throws
    func loadViewState() async throws -> ViewState?
}

extension GraphStorage {
    func saveViewState(_ viewState: ViewState) throws {
        // Default: Do nothing (for storages that don't support view state)
    }
    
    func loadViewState() throws -> ViewState? {
        return nil  // Default: No state
    }
}
