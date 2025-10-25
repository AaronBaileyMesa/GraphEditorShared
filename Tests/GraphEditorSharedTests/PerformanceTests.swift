//
//  PerformanceTests.swift
//  GraphEditorShared
//
//  Created by handcart on 9/25/25.
//

import Foundation  // For Dare
import CoreGraphics  // For CGPoint
import Testing
@testable import GraphEditorShared

struct PerformanceTests {
    
    @available(watchOS 9.0, *)  // Guard for availability
    @Test(.timeLimit(.minutes(1)))
    func testSimulationPerformance() {
        let engine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        var nodes: [any NodeProtocol] = (1...100).map { Node(label: $0, position: CGPoint(x: CGFloat.random(in: 0...300), y: CGFloat.random(in: 0...300))) }
        let edges: [GraphEdge] = []
        
        let start = Date()
        for _ in 0..<10 {
            let (updatedNodes, _) = engine.simulationStep(nodes: nodes, edges: edges)
            nodes = updatedNodes
        }
        let duration = Date().timeIntervalSince(start)
        
        print("Duration for 10 simulation steps with 100 nodes: \(duration) seconds")
        
        #expect(duration < 0.5, "Simulation should be performant")
    }
    
    @available(watchOS 9.0, *)
    @Test(.timeLimit(.minutes(1)))
    func testSimulationPerformanceWithHierarchies() {
        let engine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        engine.useAsymmetricAttraction = true  // Enable for hierarchy testing
        var nodes: [any NodeProtocol] = []
        var edges: [GraphEdge] = []
        for i in 1...50 {  // Smaller for watchOS
            let parentID = i == 1 ? nil : UUID()  // Tree structure
            let node = ToggleNode(label: i, position: CGPoint(x: CGFloat.random(in: 0...300), y: CGFloat.random(in: 0...300)))
            nodes.append(node)
            if let parentID = parentID {
                edges.append(GraphEdge(from: parentID, target: node.id, type: .hierarchy))
            }
        }
        
        let start = Date()
        for _ in 0..<10 {
            let (updatedNodes, _) = engine.simulationStep(nodes: nodes, edges: edges)
            nodes = updatedNodes
        }
        let duration = Date().timeIntervalSince(start)
        
        print("Duration for 10 steps with 50 hierarchical nodes: \(duration) seconds")
        #expect(duration < 0.3, "Hierarchical simulation should be performant")
    }
}
