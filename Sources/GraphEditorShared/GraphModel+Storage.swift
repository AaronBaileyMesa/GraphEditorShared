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
        print("loadFromStorage started")  // Existing
        let (loadedNodes, loadedEdges) = try await storage.load()
        print("loadFromStorage: loaded \(loadedNodes.count) nodes, \(loadedEdges.count) edges")  // NEW for consistency
        self.nodes = loadedNodes.map { AnyNode($0) }
        self.edges = loadedEdges
        self.nextNodeLabel = (nodes.map { $0.unwrapped.label }.max() ?? 0) + 1
    }
    
    public func load() async {
        print("GraphModel.load() called")  // Existing
        do {
            try await loadFromStorage()
            syncCollapsedPositions()
            if let viewState = try await loadViewState() {  // NEW: Load view state during graph load
                // Apply view state if needed (e.g., publish or set properties)
                print("Loaded view state: offset \(viewState.offset), zoom \(viewState.zoomScale)")
            }
            print("GraphModel.load() succeeded; nodes: \(nodes.count), edges: \(edges.count)")  // NEW
        } catch {
            print("GraphModel.load() failed: \(error.localizedDescription)")  // Enhanced
        }
    }
    
    public func save() async {
        print("GraphModel.save() called; nodes: \(nodes.count), edges: \(edges.count)")  // Existing
        do {
            try await storage.save(nodes: nodes.map { $0.unwrapped }, edges: edges)
            print("GraphModel.save() succeeded")  // Existing
        } catch {
            print("GraphModel.save() failed: \(error.localizedDescription)")  // Existing
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
            print("clearGraph called")  // NEW
            nodes = []
            edges = []
            nextNodeLabel = 1
            do {
                try await storage.clear()
                try await storage.saveViewState(ViewState(offset: .zero, zoomScale: 1.0, selectedNodeID: nil, selectedEdgeID: nil))  // NEW: Clear view state too
                print("clearGraph succeeded")  // Existing
            } catch {
                print("clearGraph failed: \(error.localizedDescription)")  // Existing
            }
            objectWillChange.send()
        }
    }
