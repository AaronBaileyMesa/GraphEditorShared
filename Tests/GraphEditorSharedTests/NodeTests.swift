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
    
    // MARK: - NodeContent Tests
    
    @Test func testNodeContentStringTruncation() {
        let short = NodeContent.string("Hello")
        #expect(short.displayText == "Hello", "Short string should not truncate")
        
        let long = NodeContent.string("This is a very long string")
        #expect(long.displayText.hasSuffix("…"), "Long string should have ellipsis")
        #expect(long.displayText.count == 11, "Truncated string should be 10 chars + ellipsis")
    }
    
    @Test func testNodeContentDateDisplay() {
        let date = Date(timeIntervalSince1970: 1700000000)  // Fixed date for testing
        let content = NodeContent.date(date)
        let display = content.displayText
        
        // Should contain some date components (exact format depends on locale)
        #expect(!display.isEmpty, "Date display should not be empty")
        #expect(display.count > 5, "Date display should have reasonable length")
    }
    
    @Test func testNodeContentNumberFormatting() {
        let whole = NodeContent.number(42.0)
        #expect(whole.displayText == "42.00", "Whole number should show 2 decimals")
        
        let decimal = NodeContent.number(3.14159)
        #expect(decimal.displayText == "3.14", "Should round to 2 decimal places")
        
        let negative = NodeContent.number(-5.5)
        #expect(negative.displayText == "-5.50", "Negative numbers should format correctly")
    }
    
    @Test func testNodeContentBooleanDisplay() {
        let trueContent = NodeContent.boolean(true)
        #expect(trueContent.displayText == "True")
        
        let falseContent = NodeContent.boolean(false)
        #expect(falseContent.displayText == "False")
    }
    
    @Test func testNodeContentEquality() {
        #expect(NodeContent.string("test") == NodeContent.string("test"))
        #expect(NodeContent.string("test") != NodeContent.string("other"))
        
        #expect(NodeContent.number(42.0) == NodeContent.number(42.0))
        #expect(NodeContent.number(42.0) != NodeContent.number(43.0))
        
        #expect(NodeContent.boolean(true) == NodeContent.boolean(true))
        #expect(NodeContent.boolean(true) != NodeContent.boolean(false))
        
        // Different types should not be equal
        #expect(NodeContent.string("42") != NodeContent.number(42.0))
    }
    
    @Test func testNodeContentCodableRoundTrip() throws {
        let contents: [NodeContent] = [
            .string("Test String"),
            .date(Date(timeIntervalSince1970: 1234567890)),
            .number(123.456),
            .boolean(true)
        ]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for content in contents {
            let encoded = try encoder.encode(content)
            let decoded = try decoder.decode(NodeContent.self, from: encoded)
            #expect(content == decoded, "Content should survive encode/decode: \(content)")
        }
    }
    
    @Test func testNodeContentDecodingInvalidType() throws {
        let invalidJSON = """
        {"type": "invalid", "value": "test"}
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(NodeContent.self, from: invalidJSON)
        }
    }
    
    @Test func testNodeWithContents() {
        let contents: [NodeContent] = [
            .string("Title"),
            .number(42.0),
            .date(Date())
        ]
        
        let node = Node(
            label: 1,
            position: .zero,
            contents: contents
        )
        
        #expect(node.contents.count == 3)
        #expect(node.contents[0] == .string("Title"))
        #expect(node.contents[1] == .number(42.0))
    }
    
    @Test func testNodeWithMethodPreservesContents() {
        let originalContents: [NodeContent] = [.string("Test"), .number(100.0)]
        let node = Node(label: 1, position: .zero, contents: originalContents)
        
        let moved = node.with(position: CGPoint(x: 10, y: 20), velocity: .zero)
        #expect(moved.contents == originalContents, "with() should preserve contents")
        
        let newContents: [NodeContent] = [.boolean(true)]
        let updated = node.with(position: .zero, velocity: .zero, contents: newContents)
        #expect(updated.contents == newContents, "with(contents:) should update contents")
    }
    
    @Test func testNodeContentsCodableRoundTrip() throws {
        let node = Node(
            label: 42,
            position: CGPoint(x: 100, y: 200),
            contents: [
                .string("Hello"),
                .number(3.14),
                .boolean(true),
                .date(Date(timeIntervalSince1970: 1700000000))
            ]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(node)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Node.self, from: data)
        
        #expect(decoded.contents.count == 4)
        #expect(decoded.contents[0] == .string("Hello"))
        #expect(decoded.contents[1] == .number(3.14))
        #expect(decoded.contents[2] == .boolean(true))
    }
}
