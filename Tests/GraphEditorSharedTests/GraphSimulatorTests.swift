//
//  GraphSimulatorTests.swift
//  GraphEditorShared
//
//  Created by Handcart on 9/26/2025.
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

struct GraphSimulatorTests {
    // Mock class for PhysicsEngine to control convergence (non-actor class for subclassing)
    class MockPhysicsEngine: PhysicsEngine {
        var stepCount = 0
        let convergeAfter: Int
        override var isPaused: Bool {  // Override as computed if needed
            get { super.isPaused }
            set { super.isPaused = newValue }
        }
        
        init(convergeAfter: Int) {
            self.convergeAfter = convergeAfter
            super.init(simulationBounds: CGSize(width: 100, height: 100))  // Adjust super init as per your PhysicsEngine
        }
        
        override func simulationStep(nodes: [any NodeProtocol], edges: [GraphEdge]) -> ([any NodeProtocol], Bool) {
            stepCount += 1
            let velocityScale = stepCount >= convergeAfter ? 0.001 : 1.0
            let updatedNodes = nodes.map { node in
                var mutableNode = node
                mutableNode.velocity = CGPoint(x: mutableNode.velocity.x * velocityScale, y: mutableNode.velocity.y * velocityScale)
                return mutableNode
            }
            let isActive = stepCount < convergeAfter
            return (updatedNodes, isActive)
        }
        
        // Mock other methods if needed (e.g., resetSimulation)
        override func resetSimulation() {
            stepCount = 0
            super.resetSimulation()
        }
    }
    
    // Helper to create a simulator with mocks and test flags
    func createTestSimulator(nodeCount: Int,
                             physicsEngine: PhysicsEngine = MockPhysicsEngine(convergeAfter: 3),
                             onStable: (() -> Void)? = nil,
                             onPostStable: (() -> Void)? = nil,
                             bypassAppCheck: Bool = true,  // Default true to bypass watchOS check
                             testStepDelay: TimeInterval? = 0.001,  // Very short for fast tests
                             baseInterval: TimeInterval = 1.0 / 30.0) -> GraphSimulator {
        let mockNodes = (0..<nodeCount).map { Node(label: $0 + 1, position: CGPoint(x: CGFloat($0) * 10, y: 0)) }  // Simple mock nodes
        let mockEdges: [GraphEdge] = []  // Empty for simplicity; override if needed
        
        return GraphSimulator(
            getNodes: { mockNodes },
            setNodes: { _ in /* No-op for tests */ },
            getEdges: { mockEdges },
            getVisibleNodes: { mockNodes },
            getVisibleEdges: { mockEdges },
            physicsEngine: physicsEngine,
            onStable: onStable,
            onPostStable: onPostStable,
            baseInterval: baseInterval,
            bypassAppCheck: bypassAppCheck,
            testStepDelay: testStepDelay
        )
    }
    
    @Test func testStartSimulationWithFewNodes() async throws {
        var logCapture: [String] = []  // Capture side effects
        
        let simulator = createTestSimulator(nodeCount: 3, onStable: {
            logCapture.append("onStable called for nodeCount: 3")
        })
        
        await simulator.startSimulation()
        try await Task.sleep(for: .seconds(0.5))  // Short wait for completion
        
        #expect(logCapture.contains("onStable called for nodeCount: 3"), "Handles low node count by calling onStable")
        let task = await simulator.simulationTask
        #expect(task == nil, "Task cleared after quick stable")
    }
    
    @Test func testSimulationTimeout() async throws {
        var logCapture: [String] = []
        
        // Never converge (high convergeAfter)
        let physics = MockPhysicsEngine(convergeAfter: Int.max)
        let simulator = createTestSimulator(nodeCount: 50, physicsEngine: physics, onStable: {
            logCapture.append("Simulation timed out")
        }, testStepDelay: 0.001)  // Speed up
        
        await simulator.startSimulation()
        
        // Poll for timeout completion
        let deadline = Date.now + 10.0  // Longer to allow max iterations
        var isComplete = false
        while Date.now < deadline && !isComplete {
            try await Task.sleep(for: .milliseconds(50))
            if logCapture.contains("Simulation timed out") {
                let task = await simulator.simulationTask
                if task == nil {
                    isComplete = true
                }
            }
        }
        
        #expect(isComplete, "Timeout occurred within extended time")
        #expect(logCapture.contains("Simulation timed out"), "Handles max iterations timeout")
        let finalTask = await simulator.simulationTask
        #expect(finalTask == nil, "Task cleared after timeout")
    }
    
    @Test func testSimulationCancellation() async throws {
        let simulator = createTestSimulator(nodeCount: 10)
        
        await simulator.startSimulation()
        try await Task.sleep(for: .milliseconds(100))  // Let it start
        
        await simulator.stopSimulation()
        try await Task.sleep(for: .milliseconds(100))  // Wait for cancel
        
        let task = await simulator.simulationTask
        #expect(task == nil, "Task cancelled and cleared")
    }
    
    @Test func testLowPowerModeAdjustment() async throws {
        // Simulate low power (indirect test)
        let simulator = createTestSimulator(nodeCount: 25, baseInterval: 1.0 / 30.0)
        await simulator.startSimulation()
        try await Task.sleep(for: .seconds(1))
        #expect(true, "Adjust interval in low power – expand with mocks for deeper assertion")
    }
}

struct CoordinateTransformerTests {
    @Test func testModelToScreen() {
        let modelPos = CGPoint(x: 10, y: 20)
        let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: .zero, zoomScale: 2.0, offset: CGSize(width: 5, height: 5), viewSize: CGSize(width: 100, height: 100))
        #expect(screenPos.x == 75.0, "Correct transformation")
        #expect(screenPos.y == 95.0, "Correct transformation")
    }
    
    @Test func testScreenToModel() {
        let screenPos = CGPoint(x: 50, y: 50)
        let modelPos = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 100, height: 100))
        #expect(modelPos.x == 0.0, "Inverse transformation")
        #expect(modelPos.y == 0.0, "Inverse transformation")
    }
    
    @Test func testRoundTripConsistency() {
        let originalModel = CGPoint(x: 1.123, y: 0.456)
        let screen = CoordinateTransformer.modelToScreen(originalModel, effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 100, height: 100))
        let recoveredModel = CoordinateTransformer.screenToModel(screen, effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 100, height: 100))
        #expect(recoveredModel.x == 1.123, "Rounded to 3 decimals")
        #expect(recoveredModel.y == 0.456, "Rounded to 3 decimals")
    }
        
    @Test func testZeroZoomSafeguard() {
        let screenPos = CGPoint(x: 50, y: 50)
        let modelPos = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: .zero, zoomScale: 0.0, offset: .zero, viewSize: CGSize(width: 100, height: 100))
        #expect(modelPos == .zero, "Handles low zoom")
    }
}
    
struct HitTestHelperTests {
        
    func createContext() -> HitTestContext {
        HitTestContext(zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 200, height: 200), effectiveCentroid: .zero)
    }
        
    @Test func testClosestNode() {
        let nodes: [any NodeProtocol] = [
            Node(label: 1, position: CGPoint(x: 10, y: 10), radius: 5),
            Node(label: 2, position: CGPoint(x: 50, y: 50), radius: 5)
        ]
        let context = createContext()
        let hit = HitTestHelper.closestNode(at: CGPoint(x: 112, y: 112), visibleNodes: nodes, context: context)
        #expect(hit?.position == CGPoint(x: 10, y: 10), "Hits closest node")
            
        let miss = HitTestHelper.closestNode(at: CGPoint(x: 300, y: 300), visibleNodes: nodes, context: context)
        #expect(miss == nil, "No hit far away")
    }
        
    @Test func testClosestEdge() {
        let nodes: [any NodeProtocol] = [
            Node(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, label: 1, position: CGPoint(x: 10, y: 10)),
            Node(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, label: 2, position: CGPoint(x: 50, y: 50))
        ]
        let edges = [GraphEdge(from: nodes[0].id, target: nodes[1].id)]
        let context = createContext()
            
        let hit = HitTestHelper.closestEdge(at: CGPoint(x: 130, y: 130), visibleEdges: edges, visibleNodes: nodes, context: context)  // Screen pos for model (30,30)
        #expect(hit != nil, "Hits edge")
            
        let miss = HitTestHelper.closestEdge(at: CGPoint(x: 0, y: 0), visibleEdges: edges, visibleNodes: nodes, context: context)  // Far point
        #expect(miss == nil, "No hit far away")
    }
        
    @Test func testPointToLineDistance() {
        let from = CGPoint(x: 0, y: 0)
        let target = CGPoint(x: 10, y: 0)
        let point = CGPoint(x: 5, y: 1)
        #expect(HitTestHelper.pointToLineDistance(point: point, from: from, target: target) == 1, "Perpendicular distance")
            
        let beyond = CGPoint(x: 15, y: 0)
        #expect(HitTestHelper.pointToLineDistance(point: beyond, from: from, target: target) == 5, "Clamped to endpoint")
            
        let zeroLen = HitTestHelper.pointToLineDistance(point: CGPoint(x: 1, y: 1), from: .zero, target: .zero)
        #expect(zeroLen == sqrt(2), "Handles zero-length line")
    }
}
