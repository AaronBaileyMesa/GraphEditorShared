//
//  GraphModel+Storage.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    private func loadFromStorage() async throws {
        let (loadedNodes, loadedEdges) = try await storage.load()
        self.nodes = loadedNodes.map { AnyNode($0) }
        self.edges = loadedEdges
        self.nextNodeLabel = (nodes.map { $0.unwrapped.label }.max() ?? 0) + 1
    }

    public func load() async {
        do {
            try await loadFromStorage()
            syncCollapsedPositions()
        } catch {
            print("Failed to load graph: \(error)")
        }
    }

    public func save() async {
        do {
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
        } catch {
            print("Failed to save graph: \(error)")
        }
    }

    private func syncCollapsedPositions() {
        for parentIndex in 0..<nodes.count {
            if let toggle = nodes[parentIndex].unwrapped as? ToggleNode, !toggle.isExpanded {
                let children = edges.filter { $0.from == nodes[parentIndex].id && $0.type == .hierarchy }.map { $0.target }
                for (index, childID) in children.enumerated() {
                    guard let childIndex = nodes.firstIndex(where: { $0.id == childID }) else { continue }
                    var child = nodes[childIndex]
                    let angle = CGFloat(index) * (2 * .pi / CGFloat(children.count))
                    let jitterX = cos(angle) * 5.0
                    let jitterY = sin(angle) * 5.0
                    child.position = nodes[parentIndex].position + CGPoint(x: jitterX, y: jitterY)
                    child.velocity = .zero
                    nodes[childIndex] = child
                }
            }
        }
        objectWillChange.send()
    }

    public func clearGraph() async {
        nodes = []
        edges = []
        nextNodeLabel = 1
        try? await storage.clear()
        objectWillChange.send()
    }
}
