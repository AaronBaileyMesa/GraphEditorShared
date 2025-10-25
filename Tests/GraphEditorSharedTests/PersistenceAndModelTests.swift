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
        let dirName = "Test-SaveAndLoad"
        let manager = PersistenceManager(directoryName: dirName)
        do { try await manager.clear() } catch GraphStorageError.graphNotFound(_) { /* ignore if not present */ }
        let node = Node(id: UUID(), label: 1, position: .zero)
        let toggleNode = ToggleNode(id: UUID(), label: 2, position: .zero, isExpanded: false)
        let edge = GraphEdge(from: node.id, target: toggleNode.id)
        try await manager.save(nodes: [node, toggleNode], edges: [edge])
        
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documents.appendingPathComponent(dirName).appendingPathComponent("graph-default.json")
        #expect(fileManager.fileExists(atPath: fileURL.path), "File created")
        
        let (loadedNodes, loadedEdges) = try await manager.load()
        #expect(loadedNodes.count == 2, "Nodes loaded")
        #expect(loadedEdges.count == 1, "Edges loaded")
        #expect(loadedNodes.contains { ($0 as? Node)?.id == node.id }, "Node type and ID preserved")
        #expect(loadedNodes.contains { ($0 as? ToggleNode)?.id == toggleNode.id && ($0 as? ToggleNode)?.isExpanded == false }, "ToggleNode type, ID, and state preserved")
    }
    
    @Test func testPersistenceManagerClear() async throws {
        let dirName = "Test-Clear"
        let manager = PersistenceManager(directoryName: dirName)
        do { try await manager.clear() } catch GraphStorageError.graphNotFound(_) { /* ignore if not present */ }
        try await manager.save(nodes: [Node(id: UUID(), label: 1, position: .zero)], edges: [])
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documents.appendingPathComponent(dirName).appendingPathComponent("graph-default.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path), "File exists before clear")
        
        try await manager.clear()
        #expect(!FileManager.default.fileExists(atPath: fileURL.path), "File removed after clear")
        
        do {
            _ = try await manager.load()
            #expect(Bool(false), "Load should throw graphNotFound after clear")
        } catch GraphStorageError.graphNotFound(_) {
            #expect(true, "Load throws not found as expected")
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
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
        try await model.save()  // Add 'try' here to handle the throwing call
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
    
    @MainActor @Test func testVisibleNodesWithRecursiveHiding() async {
        let storage = MockGraphStorage()
        let physics = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = GraphModel(storage: storage, physicsEngine: physics)
        let grandparent = AnyNode(ToggleNode(label: 1, position: .zero, isExpanded: false))
        let parent = AnyNode(ToggleNode(label: 2, position: .zero, isExpanded: true))
        let child = AnyNode(Node(label: 3, position: .zero))
        model.nodes = [grandparent, parent, child]
        model.edges = [
            GraphEdge(from: grandparent.id, target: parent.id, type: .hierarchy),
            GraphEdge(from: parent.id, target: child.id, type: .hierarchy)
        ]
        let visible = model.visibleNodes()
        #expect(visible.count == 1)  // Only grandparent visible; recursion hides descendants
        #expect(visible[0].id == grandparent.id)
    }
    
    @MainActor @Test func testUndoRedoChildAddition() async {
        let storage = MockGraphStorage()
        let physics = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = GraphModel(storage: storage, physicsEngine: physics)
        let parent = AnyNode(ToggleNode(label: 1, position: .zero))
        model.nodes = [parent]
        
        await model.addChild(to: parent.id)  // Pushes undo
        #expect(model.nodes.count == 2)
        #expect(model.edges.count == 1)
        
        guard let updatedParent = model.nodes[0].unwrapped as? ToggleNode else {
            #expect(false, "Failed to cast updated parent to ToggleNode")
            return
        }
        #expect(updatedParent.children.count == 1)
        
        await model.undo()
        #expect(model.nodes.count == 1)
        #expect(model.edges.isEmpty)
        
        guard let revertedParent = model.nodes[0].unwrapped as? ToggleNode else {
            #expect(false, "Failed to cast reverted parent to ToggleNode")
            return
        }
        #expect(revertedParent.children.isEmpty)
        
        await model.redo()
        #expect(model.nodes.count == 2)
        #expect(model.edges.count == 1)
    }
}
