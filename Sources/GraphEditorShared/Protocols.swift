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
    public var offset: CGSize
    public var zoomScale: CGFloat
    public var selectedNodeID: UUID?
    public var selectedEdgeID: UUID?

    public init(
        offset: CGSize = .zero,
        zoomScale: CGFloat = 1.0,
        selectedNodeID: UUID? = nil,
        selectedEdgeID: UUID? = nil
    ) {
        self.offset = offset
        self.zoomScale = zoomScale
        self.selectedNodeID = selectedNodeID
        self.selectedEdgeID = selectedEdgeID
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
