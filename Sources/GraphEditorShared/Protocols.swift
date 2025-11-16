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

    // Explicit initializer
    public init(offset: CGPoint, zoomScale: CGFloat, selectedNodeID: UUID? = nil, selectedEdgeID: UUID? = nil) {
        self.offset = offset
        self.zoomScale = zoomScale
        self.selectedNodeID = selectedNodeID
        self.selectedEdgeID = selectedEdgeID
    }

    // Custom Codable conformance with separate keys for offset
    enum CodingKeys: String, CodingKey {
        case offsetX
        case offsetY
        case zoomScale
        case selectedNodeID
        case selectedEdgeID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let offsetX = try container.decode(CGFloat.self, forKey: .offsetX)
        let offsetY = try container.decode(CGFloat.self, forKey: .offsetY)
        offset = CGPoint(x: offsetX, y: offsetY)
        zoomScale = try container.decode(CGFloat.self, forKey: .zoomScale)
        selectedNodeID = try container.decodeIfPresent(UUID.self, forKey: .selectedNodeID)
        selectedEdgeID = try container.decodeIfPresent(UUID.self, forKey: .selectedEdgeID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(offset.x, forKey: .offsetX)
        try container.encode(offset.y, forKey: .offsetY)
        try container.encode(zoomScale, forKey: .zoomScale)
        try container.encodeIfPresent(selectedNodeID, forKey: .selectedNodeID)
        try container.encodeIfPresent(selectedEdgeID, forKey: .selectedEdgeID)
    }
}

@available(iOS 16.0, watchOS 6.0, *)
public protocol GraphStorage {
    /// Saves the full graph state, throwing on failure (e.g., encoding or writing errors).
    func saveGraphState(_ graphState: GraphState, for name: String) async throws
    /// Loads the full graph state, throwing on failure (e.g., file not found or decoding errors).
    func loadGraphState(for name: String) async throws -> GraphState
    func clear() async throws  // Unchanged (clears default graph)
    func saveViewState(_ viewState: ViewState, for name: String) throws
    func loadViewState(for name: String) throws -> ViewState?
    // Multi-graph methods (required to preserve functionality)
    func listGraphNames() async throws -> [String]
    func createNewGraph(name: String) async throws
    func deleteGraph(name: String) async throws
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
