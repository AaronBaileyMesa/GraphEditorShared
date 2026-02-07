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
            let tempEdge = GraphEdge(from: source, target: target, type: .hierarchy)  // Added type
            edges.append(tempEdge)
            if !isTree() {
                edges.removeLast()
                return
            }
            edges.removeLast()
        }
        let edge = GraphEdge(from: source, target: target, type: .association)  // Added type, assume default
        edges.append(edge)
        objectWillChange.send()
        changesPublisher.send()
    }

    // Updated bulkCollapseAll: No casting needed with protocol inheritance; mutate directly
    public func bulkCollapseAll() {
        for nodeIndex in 0..<nodes.count {
            nodes[nodeIndex].bulkCollapse()  // Direct call—types now compatible
            let childIds = nodes[nodeIndex].children
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
    
    // NEW: Overload with optional position (defaults to random). Integrates with isTree() for validation.
    @MainActor
    public func addChild(to parentID: NodeID, at position: CGPoint? = nil) async {
        Self.logger.debugLog("Adding child to parent \(parentID.uuidString.prefix(8))")
        
        pushUndo()  // Snapshot for undo
        
        guard let parentIndex = nodes.firstIndex(where: { $0.id == parentID }),
              let parent = nodes[parentIndex].unwrapped as? Node else {
            Self.logger.warning("addChild: Parent not found or not Node type – \(parentID.uuidString.prefix(8))")
            return
        }
        
        let newLabel = nextNodeLabel
        nextNodeLabel += 1
        
        // Compute position: Use provided or randomize around parent
        let newPos: CGPoint
        if let pos = position {
            newPos = pos
        } else {
            let angle = CGFloat.random(in: 0..<CGFloat.pi * 2)
            let distance = Constants.App.nodeModelRadius * 4
            newPos = parent.position + CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
        }
        
        let newNode = Node(id: NodeID(), label: newLabel, position: newPos, velocity: .zero)
        let anyNewNode = AnyNode(newNode)
        
        // Temporarily add for tree validation
        nodes.append(anyNewNode)
        edges.append(GraphEdge(from: parentID, target: newNode.id, type: .hierarchy))
        
        // Validate tree structure
        if !isTree() {
            // Rollback if invalid
            nodes.removeLast()
            edges.removeLast()
            Self.logger.warning("addChild: Aborted – would violate tree structure for parent \(parentID.uuidString.prefix(8))")
            return
        }
        
        // Append to parent's children and childOrder (mutate parent)
        var updatedParent = parent
        updatedParent.children.append(newNode.id)
        updatedParent.childOrder.append(newNode.id)  // Maintain order
        nodes[parentIndex] = AnyNode(updatedParent)
        
        objectWillChange.send()
        invalidateHiddenNodesCache()
        await resumeSimulation()
        
        // Auto-save
        do {
            try await saveGraph()
        } catch {
            Self.logger.error("Auto-save failed after addChild: \(error.localizedDescription)")
        }
    }
}
