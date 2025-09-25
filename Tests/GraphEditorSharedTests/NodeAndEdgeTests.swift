//
//  MockGraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 9/25/25.
//

import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

class MockGraphStorage: GraphStorage {
    var nodes: [any NodeProtocol] = []
    var edges: [GraphEdge] = []
    var savedViewState: ViewState?  // New: In-memory storage
    
    func save(nodes: [any NodeProtocol], edges: [GraphEdge]) throws {
        self.nodes = nodes
        self.edges = edges
    }
    
    func load() throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        (nodes, edges)
    }
    
    func clear() throws {
        nodes = []
        edges = []
        savedViewState = nil  // Clear view state too
    }
    
    // New methods
    func saveViewState(_ viewState: ViewState) async throws {
        savedViewState = viewState
    }
    
    func loadViewState() async throws -> ViewState? {
        savedViewState
    }
}

struct NodeAndEdgeTests {
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
    
    @Test func testGraphEdgeInitializationAndEquality() {
        let id = UUID()
        let from = UUID()
        let target = UUID()
        let edge1 = GraphEdge(id: id, from: from, target: target)
        let edge2 = GraphEdge(id: id, from: from, target: target)
        #expect(edge1 == edge2, "Edges with same properties should be equal")
        
        let edge3 = GraphEdge(from: target, target: from)
        #expect(edge1 != edge3, "Edges with swapped from/to should not be equal")
    }
    
    @Test func testClampingEdgeCases() {
        // Double clamping with extremes
        let infDouble = Double.infinity
        #expect(infDouble.clamped(to: 0...100) == 100, "Infinity clamps to upper")
        #expect((-infDouble).clamped(to: 0...100) == 0, "Negative infinity clamps to lower")
        
        // CGFloat clamping with extremes
        let infCGFloat = CGFloat.infinity
        #expect(infCGFloat.clamped(to: 0...100) == 100, "Infinity clamps to upper")
        #expect((-infCGFloat).clamped(to: 0...100) == 0, "Negative infinity clamps to lower")
        
        // NaN handling: Actual impl clamps to lower bound, so expect that
        let nanDouble = Double.nan
        #expect(nanDouble.clamped(to: 0...100) == 0, "NaN clamps to lower bound")
    }
    
    @Test func testDistanceEdgeCases() {
        let samePoint = CGPoint(x: 5, y: 5)
        #expect(distance(samePoint, samePoint) == 0, "Distance to self is 0")
        
        let negativePoints = CGPoint(x: -3, y: -4)
        let origin = CGPoint.zero
        #expect(distance(negativePoints, origin) == 5, "Distance with negatives is positive")
    }
    
    @Test func testDirectedEdgeCreation() {
        let edge = GraphEdge(from: UUID(), target: UUID())
        #expect(edge.from != edge.target, "Directed edge has distinct from/to")
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
    
    @Test func testGraphEdgeCodingRoundTrip() throws {
        let edge = GraphEdge(id: UUID(), from: UUID(), target: UUID())
        let encoder = JSONEncoder()
        let data = try encoder.encode(edge)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GraphEdge.self, from: data)
        #expect(edge == decoded, "Edge should encode and decode without loss")
    }
    
    // Tests for GraphModel+EdgesNodes.swift
    @MainActor @Test func testWouldCreateCycle() {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let node1ID = UUID()
        let node2ID = UUID()
        let node3ID = UUID()
        model.nodes = [
            AnyNode(Node(id: node1ID, label: 1, position: CGPoint.zero)),
            AnyNode(Node(id: node2ID, label: 2, position: CGPoint.zero)),
            AnyNode(Node(id: node3ID, label: 3, position: CGPoint.zero))
        ]
        model.edges = [
            GraphEdge(from: node1ID, target: node2ID, type: EdgeType.hierarchy),
            GraphEdge(from: node2ID, target: node3ID, type: EdgeType.hierarchy)
        ]
        
        #expect(model.wouldCreateCycle(withNewEdgeFrom: node3ID, target: node1ID, type: EdgeType.hierarchy) == true, "Should detect cycle")
        #expect(model.wouldCreateCycle(withNewEdgeFrom: node1ID, target: node3ID, type: EdgeType.hierarchy) == false, "No cycle")
        #expect(model.wouldCreateCycle(withNewEdgeFrom: node1ID, target: node2ID, type: EdgeType.association) == false, "Non-hierarchy ignores cycle check")
    }
    
    @MainActor @Test func testAddAndDeleteEdge() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let node1ID = UUID()
        let node2ID = UUID()
        model.nodes = [
            AnyNode(Node(id: node1ID, label: 1, position: CGPoint.zero)),
            AnyNode(Node(id: node2ID, label: 2, position: CGPoint.zero))
        ]
        
        await model.addEdge(from: node1ID, target: node2ID, type: EdgeType.hierarchy)
        #expect(model.edges.count == 1, "Edge should be added")
        
        let edgeID = model.edges[0].id
        await model.deleteEdge(withID: edgeID)
        #expect(model.edges.isEmpty, "Edge should be deleted")
    }
    
    @MainActor @Test func testAddNodeAndAddToggleNode() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        model.nextNodeLabel = 1
        
        await model.addNode(at: CGPoint.zero)
        #expect(model.nodes.count == 1, "Node added")
        #expect(model.nodes[0].unwrapped.label == 1, "Label set correctly")
        #expect(model.nextNodeLabel == 2, "Label incremented")
        
        await model.addToggleNode(at: CGPoint.zero)
        #expect(model.nodes.count == 2, "ToggleNode added")
        #expect(model.nodes[1].unwrapped.label == 2, "Label set correctly")
        #expect(model.nextNodeLabel == 3, "Label incremented")
    }
    
    @MainActor @Test func testAddChildAndDeleteNode() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let parentID = UUID()
        model.nodes = [AnyNode(Node(id: parentID, label: 1, position: CGPoint.zero))]
        model.nextNodeLabel = 2
        
        await model.addChild(to: parentID)
        #expect(model.nodes.count == 2, "Child added")
        #expect(model.edges.count == 1, "Hierarchy edge added")
        #expect(model.edges[0].type == EdgeType.hierarchy, "Correct edge type")
        #expect(model.nextNodeLabel == 3, "Label incremented")
        
        let childID = model.nodes[1].id
        await model.deleteNode(withID: childID)
        #expect(model.nodes.count == 1, "Child deleted")
        #expect(model.edges.isEmpty, "Edge removed")
    }
    
    // Tests for GraphModel+Helpers.swift
    @MainActor @Test func testBuildAdjacencyList() {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let node1ID = UUID()
        let node2ID = UUID()
        let node3ID = UUID()
        model.nodes = [
            AnyNode(Node(id: node1ID, label: 1, position: CGPoint.zero)),
            AnyNode(Node(id: node2ID, label: 2, position: CGPoint.zero)),
            AnyNode(Node(id: node3ID, label: 3, position: CGPoint.zero))
        ]
        model.edges = [
            GraphEdge(from: node1ID, target: node2ID, type: EdgeType.hierarchy),
            GraphEdge(from: node1ID, target: node3ID, type: EdgeType.association),
            GraphEdge(from: node2ID, target: node3ID, type: EdgeType.hierarchy)
        ]
        
        let allAdj = model.buildAdjacencyList()
        #expect(allAdj[node1ID]?.count == 2, "All edges from node1")
        #expect(allAdj[node2ID]?.count == 1, "All edges from node2")
        
        let hierarchyAdj = model.buildAdjacencyList(for: EdgeType.hierarchy)
        #expect(hierarchyAdj[node1ID]?.count == 1, "Only hierarchy from node1")
        #expect(hierarchyAdj[node1ID]?[0] == node2ID, "Correct target")
    }
    
    @MainActor @Test func testIsBidirectionalBetween() {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let node1ID = UUID()
        let node2ID = UUID()
        let node3ID = UUID()
        model.edges = [
            GraphEdge(from: node1ID, target: node2ID),
            GraphEdge(from: node2ID, target: node1ID),
            GraphEdge(from: node1ID, target: node3ID)
        ]
        
        #expect(model.isBidirectionalBetween(node1ID, node2ID) == true, "Bidirectional")
        #expect(model.isBidirectionalBetween(node1ID, node3ID) == false, "Unidirectional")
    }
    
    @MainActor @Test func testEdgesBetween() {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let node1ID = UUID()
        let node2ID = UUID()
        let edge1 = GraphEdge(from: node1ID, target: node2ID)
        let edge2 = GraphEdge(from: node2ID, target: node1ID)
        model.edges = [edge1, edge2, GraphEdge(from: node1ID, target: UUID())]
        
        let edges = model.edgesBetween(node1ID, node2ID)
        #expect(edges.count == 2, "Both directions")
        #expect(edges.contains { $0.id == edge1.id }, "Includes edge1")
        #expect(edges.contains { $0.id == edge2.id }, "Includes edge2")
    }
    
    @MainActor @Test func testHandleTapOnToggleNode() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let parentID = UUID()
        let childID = UUID()
        let parent = ToggleNode(id: parentID, label: 1, position: CGPoint(x: 100, y: 100), isExpanded: false)
        let child = Node(id: childID, label: 2, position: CGPoint.zero)
        model.nodes = [AnyNode(parent), AnyNode(child)]
        model.edges = [GraphEdge(from: parentID, target: childID, type: EdgeType.hierarchy)]
        
        await model.handleTap(on: parentID)
        let updatedParent = model.nodes[0].unwrapped as? ToggleNode
        #expect(updatedParent?.isExpanded == true, "Toggled to expanded")
        #expect(model.nodes[1].position != CGPoint.zero, "Child position offset")
        #expect(model.nodes[1].velocity == .zero, "Velocity reset")
    }
}
