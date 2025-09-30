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
}
