//
//  GraphModel+TreeSupport.swift
//  GraphEditorShared
//
//  Created by handcart on 10/27/25.
//

import Foundation
import Combine  // If needed
import os

extension GraphModel {
    // Removed stored properties—now in main class

    // Tree validation (unchanged, but confirmed working)
    public func isTree() -> Bool {
        guard !nodes.isEmpty else { return true }
        var incomingCounts = Dictionary(nodes.map { ($0.id, 0) }, uniquingKeysWith: { $1 })
        for edge in edges {
            incomingCounts[edge.target, default: 0] += 1
        }
        let roots = nodes.filter { incomingCounts[$0.id] == 0 }
        if roots.count != 1 { return false }  // Single root

        var visited = Set<UUID>()
        var stack = [roots[0].id]
        while !stack.isEmpty {
            let current = stack.removeLast()
            if visited.contains(current) { return false }  // Cycle
            visited.insert(current)
            let children = edges.filter { $0.from == current }.map { $0.target }
            stack.append(contentsOf: children)
        }
        return visited.count == nodes.count  // Connected
    }

    // Mode-enforced addEdge (unchanged)
    public func addEdge(source: UUID, target: UUID) {
        if mode == .tree {
            let tempEdge = GraphEdge(from: source, target: target)
            edges.append(tempEdge)
            if !isTree() {
                edges.removeLast()
                return
            }
            edges.removeLast()
        }
        let edge = GraphEdge(from: source, target: target)
        edges.append(edge)
        objectWillChange.send()
        changesPublisher.send()
    }

    // Updated bulkCollapseAll: No casting needed with protocol inheritance; mutate directly
    public func bulkCollapseAll() {
        for i in 0..<nodes.count {
            nodes[i].bulkCollapse()  // Direct call—types now compatible
            let childIds = nodes[i].children
            for childId in childIds {
                if let childIndex = nodes.firstIndex(where: { $0.id == childId }) {
                    nodes[childIndex].bulkCollapse()  // Direct mutation
                }
            }
        }
        objectWillChange.send()
        changesPublisher.send()
    }

    // Auto-save hook (unchanged)
    private func saveState() {
        changesPublisher.send()
    }
}
