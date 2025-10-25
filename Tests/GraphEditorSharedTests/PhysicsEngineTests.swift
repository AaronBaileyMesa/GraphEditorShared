//
//  PhysicsEngineTests.swift
//  GraphEditorShared
//
//  Created by handcart on 10/25/25.
//

import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

struct PhysicsEngineTests {
    @Test func testAsymmetricAttraction() {
        let calc = AttractionCalculator(symmetricFactor: 0.5, useAsymmetric: true)
        let node1Pos = CGPoint(x: 0, y: 0)
        let node2Pos = CGPoint(x: 100, y: 0)
        let dist = hypot(node2Pos.x - node1Pos.x, node2Pos.y - node1Pos.y)
        let node1 = Node(id: UUID(), label: 1, position: node1Pos)
        let node2 = Node(id: UUID(), label: 2, position: node2Pos)
        let edge = GraphEdge(from: node1.id, target: node2.id, type: .hierarchy)
        let forces = calc.applyAttractions(forces: [:], edges: [edge], nodes: [node1, node2])
        
        let forceMagnitude = Constants.Physics.stiffness * (dist - Constants.Physics.idealLength)
        let expectedChildPull = forceMagnitude * 2.0  // Matches asymmetricFactor
        let expectedParentBackPull = forceMagnitude * 0.1  // Matches back-pull factor
        
        // Check child pull (strong negative in x, toward parent)
        #expect(forces[node2.id]?.x ?? 0 < 0, "Child pulled toward parent")
        #expect(forces[node2.id]?.x ?? 0 <= -expectedChildPull + 1e-6, "Strong pull on child (expected ≈ \(-expectedChildPull))")  // Tolerance for FP
        
        // Check parent back-pull (minimal positive in x)
        #expect(abs(forces[node1.id]?.x ?? 0) > 0, "Some minimal back-pull on parent")
        #expect(abs(forces[node1.id]?.x ?? 0) <= expectedParentBackPull + 1e-6, "Back-pull minimal (expected ≈ \(expectedParentBackPull))")
    }

}
