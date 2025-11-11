//
//  NodeTests.swift
//  GraphEditorShared
//
//  Created by handcart on 11/6/25.
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

struct NodeTests {
    @Test func testNodeInitializationAndEquality() {
        let id = UUID()
        let node1 = Node(id: id, label: 1, position: CGPoint(x: 10, y: 20))
        let node2 = Node(id: id, label: 1, position: CGPoint(x: 10, y: 20))
        #expect(node1 == node2, "Nodes with same properties should be equal")
        
        let node3 = Node(id: UUID(), label: 2, position: .zero)
        
        #expect(node1 != node3, "Nodes with different IDs/labels should not be equal")
        
    }
    
    @Test func testNodeCodingRoundTrip() throws {
        let node = Node(id: UUID(), label: 1, position: CGPoint(x: 5, y: 10), velocity: CGPoint(x: 1, y: 2))
        let encoder = JSONEncoder()
        let data = try encoder.encode(node)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Node.self, from: data)
        #expect(node == decoded, "Node should encode and decode without data loss")
    }

    @MainActor @Test func testHandleTapOnToggleNode() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let parentID = UUID()
        let childID = UUID()
        let parent = ToggleNode(id: parentID, label: 1, position: CGPoint(x: 100, y: 100), isExpanded: false, children: [childID])
        let child = Node(id: childID, label: 2, position: .zero)
        model.nodes = [AnyNode(parent), AnyNode(child)]
        model.edges = [GraphEdge(from: parentID, target: childID, type: EdgeType.hierarchy)]
        
        await model.handleTap(on: parentID)
        let updatedParent = model.nodes[0].unwrapped as? ToggleNode
        print("Test Post-handleTap: updatedParent isExpanded: \(updatedParent?.isExpanded.description ?? "nil")")
        #expect(updatedParent?.isExpanded == true, "Toggled to expanded")
        print("testHandleTapOnToggleNode")
        print(updatedParent?.isExpanded ?? "nil")
        
        #expect(updatedParent?.isExpanded == true, "Toggled to expanded")
        #expect(model.nodes[1].position != .zero, "Child position offset")
    }
    
    @MainActor @Test func testSortChildren() async {
        let storage = MockGraphStorage()
        let physics = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = GraphModel(storage: storage, physicsEngine: physics)
        let parentID = UUID()
        let child1 = AnyNode(Node(id: UUID(), label: 3, position: .zero))  // Unsorted labels
        let child2 = AnyNode(Node(id: UUID(), label: 1, position: .zero))
        let child3 = AnyNode(Node(id: UUID(), label: 2, position: .zero))
        let parent = AnyNode(ToggleNode(id: parentID, label: 0, position: .zero, children: [child1.id, child2.id, child3.id], childOrder: [child1.id, child2.id, child3.id]))
        model.nodes = [parent, child1, child2, child3]
        
        await model.sortChildren(of: parentID, by: \.label)
        let sortedParent = model.nodes[0].unwrapped as? ToggleNode
        #expect(sortedParent?.childOrder == [child2.id, child3.id, child1.id])  // Sorted by label: 1,2,3
        #expect(sortedParent?.children == [child1.id, child2.id, child3.id])  // children unchanged
        
        await model.undo()  // Test revert
        let undoneParent = model.nodes[0].unwrapped as? ToggleNode
        #expect(undoneParent?.childOrder == [child1.id, child2.id, child3.id])  // Original order
    }
    
    @Test func testNodeDecodingWithMissingKeys() throws {
        // Test partial data to cover error paths in init(from decoder:)
        let json = "{\"id\": \"\(UUID())\", \"label\": 1}"  // Missing position/velocity
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(Node.self, from: data)
        }
    }
    
    @MainActor @Test func testAddChildUpdatesToggleNodeArrays() async {
        let storage = MockGraphStorage()
        let physics = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = GraphModel(storage: storage, physicsEngine: physics)
        let parent = AnyNode(ToggleNode(label: 1, position: .zero))
        model.nodes = [parent]
        await model.addPlainChild(to: parent.id)
        let updatedParent = model.nodes.first(where: { $0.id == parent.id })?.unwrapped as? ToggleNode
        #expect(updatedParent?.children.count == 1)
        #expect(updatedParent?.childOrder.count == 1)
        #expect(updatedParent?.childOrder == updatedParent?.children)  // Order matches
        #expect(model.edges.count == 1)  // Edge added
    }

    @MainActor @Test func testToggleNodeChildOrdering() {
        let child1 = UUID(), child2 = UUID(), child3 = UUID()
        let node = ToggleNode(label: 1, position: .zero, children: [child1, child2, child3], childOrder: [child3, child1, child2])
        #expect(node.childOrder == [child3, child1, child2])
        let reordered = node.with(childOrder: [child2, child3, child1])
        #expect(reordered.childOrder == [child2, child3, child1])
        #expect(reordered.children == [child1, child2, child3])  // Unchanged
        // If sorting implemented: model.sortChildren(of: node.id, by: \.label); expect order
    }
}
