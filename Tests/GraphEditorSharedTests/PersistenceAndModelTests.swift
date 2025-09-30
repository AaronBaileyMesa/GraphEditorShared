//
//  PersistenceAndModelTests.swift
//  GraphEditorShared
//
//  Created by handcart on 9/25/25.
//

import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

// Assuming MockGraphStorage is defined in NodeAndEdgeTests.swift or import it if shared.

struct PersistenceAndModelTests {
    // Tests for PersistenceManager.swift
    @Test func testPersistenceManagerSaveAndLoad() async throws {
        let manager = PersistenceManager(fileName: "testSaveAndLoad.json")  // Unique file
        try await manager.clear()  // Clear any existing for safety
        let node = Node(id: UUID(), label: 1, position: .zero)
        let toggleNode = ToggleNode(id: UUID(), label: 2, position: .zero, isExpanded: false)
        let edge = GraphEdge(from: node.id, target: toggleNode.id)
        try await manager.save(nodes: [node, toggleNode], edges: [edge])
        
        let fileManager = FileManager.default
        #expect(fileManager.fileExists(atPath: manager.fileURL.path), "File created")
        
        let (loadedNodes, loadedEdges) = try await manager.load()
        #expect(loadedNodes.count == 2, "Nodes loaded")
        #expect(loadedEdges.count == 1, "Edges loaded")
        #expect(loadedNodes.contains { ($0 as? Node)?.id == node.id }, "Node type and ID preserved")
        #expect(loadedNodes.contains { ($0 as? ToggleNode)?.id == toggleNode.id && ($0 as? ToggleNode)?.isExpanded == false }, "ToggleNode type, ID, and state preserved")
    }
    
    @Test func testPersistenceManagerClear() async throws {
        let manager = PersistenceManager(fileName: "testClear.json")  // Unique file
        try await manager.clear()  // Start clean
        try await manager.save(nodes: [Node(id: UUID(), label: 1, position: .zero)], edges: [])
        #expect(FileManager.default.fileExists(atPath: manager.fileURL.path), "File exists before clear")
        
        try await manager.clear()
        #expect(!FileManager.default.fileExists(atPath: manager.fileURL.path), "File removed after clear")
        
        let (nodes, edges) = try await manager.load()
        #expect(nodes.isEmpty && edges.isEmpty, "Load returns empty after clear")
    }
  
    // Tests for GraphModel+Storage.swift
    @MainActor @Test(.timeLimit(.minutes(1)))
    func testLoadAndSaveWithMockStorage() async throws {
        let mockStorage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: mockStorage, physicsEngine: physicsEngine)
        let node = Node(id: UUID(), label: 1, position: CGPoint.zero)
        let edge = GraphEdge(from: node.id, target: UUID())
        mockStorage.nodes = [node]
        mockStorage.edges = [edge]
        
        await model.load()
        #expect(model.nodes.count == 1, "Loaded nodes")
        #expect(model.edges.count == 1, "Loaded edges")
        #expect(model.nextNodeLabel == 2, "Next label set")
        
        let newNode = Node(id: UUID(), label: 2, position: CGPoint.zero)
        model.nodes.append(AnyNode(newNode))
        await model.save()
        #expect(mockStorage.nodes.count == 2, "Saved nodes")
        #expect(mockStorage.edges.count == 1, "Saved edges")
    }
    
    @MainActor @Test(.timeLimit(.minutes(1)))
    func testClearGraphWithMockStorage() async throws {
        let mockStorage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: mockStorage, physicsEngine: physicsEngine)
        model.nodes = [AnyNode(Node(id: UUID(), label: 1, position: CGPoint.zero))]
        model.edges = [GraphEdge(from: UUID(), target: UUID())]
        model.nextNodeLabel = 5
        
        await model.clearGraph()
        #expect(model.nodes.isEmpty, "Nodes cleared")
        #expect(model.edges.isEmpty, "Edges cleared")
        #expect(model.nextNodeLabel == 1, "Label reset")
        #expect(mockStorage.nodes.isEmpty, "Storage cleared")
        #expect(mockStorage.edges.isEmpty, "Storage cleared")
    }
    
    @MainActor @Test func testSyncCollapsedPositions() async {
        let storage = MockGraphStorage()
        let parentID = UUID()
        let child1ID = UUID()
        let child2ID = UUID()
        let parent = ToggleNode(id: parentID, label: 1, position: CGPoint(x: 100, y: 100), isExpanded: false)
        let child1 = Node(id: child1ID, label: 2, position: CGPoint.zero)
        let child2 = Node(id: child2ID, label: 3, position: CGPoint.zero)
        storage.nodes = [parent, child1, child2]
        storage.edges = [
            GraphEdge(from: parentID, target: child1ID, type: EdgeType.hierarchy),
            GraphEdge(from: parentID, target: child2ID, type: EdgeType.hierarchy)
        ]
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        await model.load()  // Calls syncCollapsedPositions internally
        #expect(approximatelyEqual(model.nodes[1].position, model.nodes[0].position, accuracy: 6), "Child1 close to parent")
        #expect(approximatelyEqual(model.nodes[2].position, model.nodes[0].position, accuracy: 6), "Child2 close to parent")
        #expect(model.nodes[1].velocity == .zero, "Velocity reset")
    }
}
