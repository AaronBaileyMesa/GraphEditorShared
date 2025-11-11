//
//  EdgeTests.swift
//  GraphEditorShared
//
//  Created by handcart on 11/6/25.
//

import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

struct EdgeTests {
    
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
    
    @Test func testDirectedEdgeCreation() {
        let edge = GraphEdge(from: UUID(), target: UUID())
        #expect(edge.from != edge.target, "Directed edge has distinct from/to")
    }
    
    @Test func testGraphEdgeCodingRoundTrip() throws {
        let edge = GraphEdge(id: UUID(), from: UUID(), target: UUID())
        let encoder = JSONEncoder()
        let data = try encoder.encode(edge)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GraphEdge.self, from: data)
        #expect(edge == decoded, "Edge should encode and decode without loss")
    }
}
