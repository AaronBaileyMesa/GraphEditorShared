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
        let edge = GraphEdge(from: node.id, target: toggleNode.id, type: .hierarchy)  // Add type if required by init
        
        // Wrap in GraphState with defaults
        let state = GraphState(
            nodes: [AnyNode(node), AnyNode(toggleNode)],
            edges: [edge],
            hierarchyEdgeColor: CodableColor(.blue),
            associationEdgeColor: CodableColor(.white)
        )
        //try await manager.save(graphState: state, for: "default")
        try await manager.saveGraphState(state, for: "default")
        
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documents.appendingPathComponent(dirName).appendingPathComponent("graph-default.json")
        #expect(fileManager.fileExists(atPath: fileURL.path), "File created")
        
        let loadedState = try await manager.loadGraphState(for: "default")
        #expect(loadedState.nodes.count == 2, "Nodes loaded")
        #expect(loadedState.edges.count == 1, "Edges loaded")
        #expect(loadedState.nodes.contains { ($0 as? Node)?.id == node.id }, "Node type and ID preserved")
        #expect(loadedState.nodes.contains { ($0 as? ToggleNode)?.id == toggleNode.id && ($0 as? ToggleNode)?.isExpanded == false }, "ToggleNode type, ID, and state preserved")
    }
    
    @Test func testPersistenceManagerClear() async throws {
        let dirName = "Test-Clear"
        let manager = PersistenceManager(directoryName: dirName)
        do { try await manager.clear() } catch GraphStorageError.graphNotFound(_) { /* ignore if not present */ }
        let node = Node(id: UUID(), label: 1, position: .zero)
        
        // Wrap in GraphState with defaults
        let state = GraphState(
            nodes: [AnyNode(node)],
            edges: [],
            hierarchyEdgeColor: CodableColor(.blue),
            associationEdgeColor: CodableColor(.white)
        )
        try await manager.saveGraphState(state, for: "default")
        
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documents.appendingPathComponent(dirName).appendingPathComponent("graph-default.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path), "File exists before clear")
        
        try await manager.clear()
        #expect(!FileManager.default.fileExists(atPath: fileURL.path), "File removed after clear")
        
        do {
            _ = try await manager.loadGraphState(for: "default")
            #expect(Bool(false), "Load should throw graphNotFound after clear")
        } catch let error as GraphStorageError {
            if case .graphNotFound(_) = error {
                #expect(true, "Load throws not found as expected")
            } else {
                #expect(Bool(false), "Unexpected GraphStorageError variant: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
    
    // Tests for GraphModel+Storage.swift
    @MainActor @Test(.timeLimit(.minutes(1)))
    func testLoadAndSaveWithMockStorage() async throws {
        let mockStorage = MockGraphStorage()
        let physics = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: mockStorage, physicsEngine: physics)
        
        let node1 = AnyNode(Node(label: 1, position: .zero))
        let node2 = AnyNode(ToggleNode(label: 2, position: .zero, isExpanded: false))  // Add a ToggleNode for variety
        model.nodes = [node1, node2]
        model.edges = [GraphEdge(from: node1.id, target: node2.id)]
        model.nextNodeLabel = 3  // Adjusted for 2 nodes
        
        try await model.saveGraph()
        #expect(mockStorage.nodes.count == 2, "Saved nodes")  // Now matches
        #expect(mockStorage.edges.count == 1, "Saved edges")
        
        let loadedModel = GraphModel(storage: mockStorage, physicsEngine: physics)
        await loadedModel.loadGraph()
        #expect(loadedModel.nodes.count == 2, "Loaded nodes")
        #expect(loadedModel.edges.count == 1, "Loaded edges")
        #expect(loadedModel.nextNodeLabel == 3, "Next label set")
    }
    
    @MainActor @Test(.timeLimit(.minutes(1)))
    func testClearGraphWithMockStorage() async throws {
        let mockStorage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: mockStorage, physicsEngine: physicsEngine)
        model.nodes = [AnyNode(Node(id: UUID(), label: 1, position: CGPoint.zero))]
        model.edges = [GraphEdge(from: UUID(), target: UUID())]
        model.nextNodeLabel = 5
        
        await model.resetGraph()
        #expect(model.nodes.isEmpty, "Nodes cleared")
        #expect(model.edges.isEmpty, "Edges cleared")
        #expect(model.nextNodeLabel == 1, "Label reset")
        #expect(mockStorage.nodes.isEmpty, "Storage cleared")
        #expect(mockStorage.edges.isEmpty, "Storage cleared")
    }
    
    @MainActor @Test func testSyncCollapsedPositions() async {
        let storage = MockGraphStorage()
        let physics = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = GraphModel(storage: storage, physicsEngine: physics)
        let parent = AnyNode(ToggleNode(label: 1, position: CGPoint(x: 100, y: 100), isExpanded: false))
        let child1 = AnyNode(Node(label: 2, position: .zero))
        let child2 = AnyNode(Node(label: 3, position: .zero))
        model.nodes = [parent, child1, child2]
        model.edges = [
            GraphEdge(from: parent.id, target: child1.id, type: .hierarchy),
            GraphEdge(from: parent.id, target: child2.id, type: .hierarchy)
        ]
        
        model.syncCollapsedPositions()  // No await needed (function is sync)
        
        // Debug print (remove after)
        print("After sync, nodes.count = \(model.nodes.count)")
        
        guard let child1Index = model.nodes.firstIndex(where: { $0.id == child1.id }),
              let child2Index = model.nodes.firstIndex(where: { $0.id == child2.id }) else {
            #expect(Bool(false), "Children not found after sync")
            return
        }
        
        #expect(approximatelyEqual(model.nodes[child1Index].position, parent.unwrapped.position, accuracy: 6), "Child1 close to parent")
        #expect(approximatelyEqual(model.nodes[child2Index].position, parent.unwrapped.position, accuracy: 6), "Child2 close to parent")
        #expect(model.nodes[child1Index].velocity == .zero, "Child1 velocity reset")
        #expect(model.nodes[child2Index].velocity == .zero, "Child2 velocity reset")  // Added for completeness
    }
        
    @MainActor @Test func testUndoRedoChildAddition() async {
        let storage = MockGraphStorage()
        let physics = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = GraphModel(storage: storage, physicsEngine: physics)
        let parent = AnyNode(ToggleNode(label: 1, position: .zero))
        model.nodes = [parent]
        
        await model.addPlainChild(to: parent.id)  // Pushes undo
        #expect(model.nodes.count == 2)
        #expect(model.edges.count == 1)
        
        guard let updatedParent = model.nodes[0].unwrapped as? ToggleNode else {
            #expect(Bool(false), "Failed to cast updated parent to ToggleNode")
            return
        }
        #expect(updatedParent.children.count == 1)
        
        await model.undo()
        #expect(model.nodes.count == 1)
        #expect(model.edges.isEmpty)
        
        guard let revertedParent = model.nodes[0].unwrapped as? ToggleNode else {
            #expect(Bool(false), "Failed to cast reverted parent to ToggleNode")
            return
        }
        #expect(revertedParent.children.isEmpty)
        
        await model.redo()
        #expect(model.nodes.count == 2)
        #expect(model.edges.count == 1)
    }
}
