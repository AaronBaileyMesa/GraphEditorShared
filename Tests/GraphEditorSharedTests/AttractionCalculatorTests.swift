//
//  AttractionCalculatorTests.swift
//  GraphEditorShared
//
//  Created by handcart on 10/27/25.
//


import XCTest
@testable import GraphEditorShared

class AttractionCalculatorTests: XCTestCase {
    
    func testPreferredAngles_SingleChild_DownwardPull() {
        let parentID = UUID()
        let childID = UUID()
        let parent = ToggleNode(id: parentID, label: 1, position: .zero, children: [childID], childOrder: [childID])
        let child = Node(id: childID, label: 2, position: CGPoint(x: 50, y: 0))  // To the right, should pull down
        let nodes: [any NodeProtocol] = [parent, child]
        let edges = [GraphEdge(from: parentID, target: childID, type: .hierarchy)]
        
        let calc = AttractionCalculator(symmetricFactor: 0.5, useAsymmetric: true, usePreferredAngles: true)
        let forces = calc.applyAttractions(forces: [:], edges: edges, nodes: nodes)
        
        let childForce = forces[childID] ?? .zero
        XCTAssertGreaterThan(childForce.y, 0, "Should pull child downward (positive y)")
        XCTAssertEqual(childForce.x, 0, accuracy: 1e-5, "No horizontal torque for centered child")
    }
    
    func testPreferredAngles_Disabled_NoTorque() {
        let parentID = UUID()
        let childID = UUID()
        let parent = ToggleNode(id: parentID, label: 1, position: .zero, children: [childID], childOrder: [childID])
        let child = Node(id: childID, label: 2, position: CGPoint(x: 50, y: 0))
        let nodes: [any NodeProtocol] = [parent, child]
        let edges = [GraphEdge(from: parentID, target: childID, type: .hierarchy)]
        
        let calc = AttractionCalculator(symmetricFactor: 0.5, useAsymmetric: true, usePreferredAngles: false)
        let forces = calc.applyAttractions(forces: [:], edges: edges, nodes: nodes)
        
        let childForce = forces[childID] ?? .zero
        // Assert no additional torque (just asymmetric attraction)
        XCTAssertLessThan(childForce.x, 0, "Asymmetric pull toward parent (negative x)")
        XCTAssertEqual(childForce.y, 0, accuracy: 1e-5, "No y-force without torque")
    }
}