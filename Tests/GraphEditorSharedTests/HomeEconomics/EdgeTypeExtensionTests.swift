//
//  EdgeTypeExtensionTests.swift
//  GraphEditorSharedTests
//
//  Tests for home economics edge type extensions
//

import Testing
@testable import GraphEditorShared

struct EdgeTypeExtensionTests {

    @Test("EdgeType includes home economics types")
    func testHomeEconEdgeTypes() {
        // Should compile without errors
        let ownership: EdgeType = .ownership
        let allocation: EdgeType = .allocation
        let payment: EdgeType = .payment
        let attribution: EdgeType = .attribution

        #expect(ownership.rawValue == "ownership")
        #expect(allocation.rawValue == "allocation")
        #expect(payment.rawValue == "payment")
        #expect(attribution.rawValue == "attribution")
    }

    @Test("Home econ edge types are Codable")
    func testHomeEconEdgesCodable() throws {
        let edge = GraphEdge(from: UUID(), target: UUID(), type: .ownership)
        let encoded = try JSONEncoder().encode(edge)
        let decoded = try JSONDecoder().decode(GraphEdge.self, from: encoded)
        #expect(decoded.type == .ownership)
    }

    @Test("Existing edge types still work")
    func testBackwardCompatibility() {
        // Ensure we didn't break existing types
        let hier: EdgeType = .hierarchy
        let assoc: EdgeType = .association
        let spring: EdgeType = .spring

        #expect(hier.rawValue == "hierarchy")
        #expect(assoc.rawValue == "association")
        #expect(spring.rawValue == "spring")
    }
}
