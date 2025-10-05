//
//  Protocols.swift
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

    // Explicit initializer to fix "Extra arguments" error
    public init(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID? = nil, selectedEdgeID: UUID? = nil) {
        self.offset = offset
        self.zoomScale = zoomScale
        self.selectedNodeID = selectedNodeID
        self.selectedEdgeID = selectedEdgeID
    }

    // Custom Codable conformance to handle decoding/encoding
    enum CodingKeys: String, CodingKey {
        case offset
        case zoomScale
        case selectedNodeID
        case selectedEdgeID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let offsetX = try container.decode(CGFloat.self, forKey: .offset)
        let offsetY = try container.decode(CGFloat.self, forKey: .offset)
        offset = CGPoint(x: offsetX, y: offsetY)  // Assuming offset is encoded as two values; adjust if encoded as dict/array
        zoomScale = try container.decode(CGFloat.self, forKey: .zoomScale)
        selectedNodeID = try container.decodeIfPresent(UUID.self, forKey: .selectedNodeID)
        selectedEdgeID = try container.decodeIfPresent(UUID.self, forKey: .selectedEdgeID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(offset.x, forKey: .offset)  // Adjust encoding if needed
        try container.encode(offset.y, forKey: .offset)
        try container.encode(zoomScale, forKey: .zoomScale)
        try container.encodeIfPresent(selectedNodeID, forKey: .selectedNodeID)
        try container.encodeIfPresent(selectedEdgeID, forKey: .selectedEdgeID)
    }
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
    // Multi-graph methods (required to preserve functionality)
    func listGraphNames() async throws -> [String]
    func createNewGraph(name: String) async throws
    func save(nodes: [any NodeProtocol], edges: [GraphEdge], for name: String) async throws
    func load(for name: String) async throws -> (nodes: [any NodeProtocol], edges: [GraphEdge])
    func deleteGraph(name: String) async throws
    func saveViewState(_ viewState: ViewState, for name: String) throws
    func loadViewState(for name: String) throws -> ViewState?
}

@available(iOS 16.0, watchOS 6.0, *)
extension GraphStorage {
    func saveViewState(_ viewState: ViewState) throws {
        // Default: Do nothing (for storages that don't support view state)
    }
    
    func loadViewState() throws -> ViewState? {
        return nil  // Default: No state
    }
}
