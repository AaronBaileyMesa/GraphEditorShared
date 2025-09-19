//
//  GraphModel+Visibility.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//
import Foundation

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    public func visibleNodes() -> [any NodeProtocol] {
        let hidden = hiddenNodeIDs
        return nodes.filter { !hidden.contains($0.id) }.map { $0.unwrapped }
    }

    public func visibleEdges() -> [GraphEdge] {
        let hidden = hiddenNodeIDs
        return edges.filter { !hidden.contains($0.from) && !hidden.contains($0.target) }
    }

    public func boundingBox() -> CGRect {
        self.physicsEngine.boundingBox(nodes: nodes.map { $0.unwrapped })
    }

    public func centerGraph() {
        let centered = physicsEngine.centerNodes(nodes: nodes.map { $0.unwrapped })
        nodes = centered.map { AnyNode($0) }
        objectWillChange.send()
    }

    public func expandAllRoots() async {
        for var root in buildRoots() {
            root.isExpanded = true
            if let index = nodes.firstIndex(where: { $0.id == root.id }) {
                nodes[index] = AnyNode(root)
            }
        }
        objectWillChange.send()
    }

    private func buildRoots() -> [any NodeProtocol] {
        var incoming = Set<NodeID>()
        for edge in edges {
            incoming.insert(edge.target)
        }
        return nodes.filter { !incoming.contains($0.id) }.map { $0.unwrapped }
    }
}
