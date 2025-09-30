//
//  GraphSimulatorTests.swift
//  GraphEditorShared
//
//  Created by Grok on 9/26/2025. (AI-generated for increased coverage)
//

import Testing
import Foundation
import CoreGraphics
import WatchKit  // Added for WKApplication in watchOS guard
@testable import GraphEditorShared

struct GraphSimulatorTests {
    // Test subclass to bypass watchOS guard in tests
    class TestGraphSimulator: GraphSimulator {
        @MainActor
        override func startSimulation() async {
            print("Starting simulation with nodeCount: \(getNodes().count)")
#if os(watchOS)
            // Optionally remove this entire block if not testing watchOS:
            // guard WKApplication.shared().applicationState == .active else { return }
#endif
            physicsEngine.resetSimulation()
            self.recentVelocities.removeAll()
            
            let nodeCount = getNodes().count
            if nodeCount < 5 { return }
            
            var adjustedInterval = baseInterval
            if nodeCount >= 20 {
                adjustedInterval = nodeCount < 50 ? 1.0 / 15.0 : 1.0 / 10.0
            }
            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                adjustedInterval *= 2.0
            }
            
            simulationTask = Task {
                print("Simulation task started")
                await self.runSimulationLoop(baseInterval: adjustedInterval, nodeCount: nodeCount)
                print("Simulation task ended")
            }
            await simulationTask?.value
        }
    }
    
    public func createSimulator(nodeCount: Int = 5, withVisible: Bool = true, withEdges: Bool = false, forTesting: Bool = false, onStable: (() -> Void)? = nil) -> GraphSimulator {
        var nodes: [any NodeProtocol] = (1...nodeCount).map { Node(label: $0, position: CGPoint(x: CGFloat.random(in: 0...100), y: CGFloat.random(in: 0...100))) }
        var edges: [GraphEdge] = []
        if withEdges {
            edges = (0..<nodeCount-1).map { GraphEdge(from: nodes[$0].id, target: nodes[$0+1].id) }
        }
        
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 3000, height: 3000))
        
        if forTesting {
            return TestGraphSimulator(
                getNodes: { nodes },
                setNodes: { newNodes in nodes = newNodes },
                getEdges: { edges },
                getVisibleNodes: { withVisible ? nodes : [] },
                getVisibleEdges: { withVisible ? edges : [] },
                physicsEngine: physicsEngine,
                onStable: onStable
            )
        } else {
            return GraphSimulator(
                getNodes: { nodes },
                setNodes: { newNodes in nodes = newNodes },
                getEdges: { edges },
                getVisibleNodes: { withVisible ? nodes : [] },
                getVisibleEdges: { withVisible ? edges : [] },
                physicsEngine: physicsEngine,
                onStable: onStable  // Pass the onStable callback here
            )
        }
    }
    
    @MainActor @Test func testStartSimulationLowNodeCount() async {
        let simulator = createSimulator(nodeCount: 4)
        await simulator.startSimulation()
        #expect(simulator.simulationTask == nil, "Should not start for <5 nodes")
    }
    
    @MainActor @Test(.timeLimit(.minutes(1)))
    func testStartSimulationAdjustedInterval() async {
        let simulator = createSimulator(nodeCount: 30, withEdges: true, forTesting: true)
        await simulator.startSimulation()
        #expect(simulator.simulationTask != nil, "Task should start")
        await simulator.stopSimulation()
    }
    
    @Test func testComputeSimulationStep() {
        let simulator = createSimulator()
        let result = simulator.computeSimulationStep()
        #expect(!result.updatedNodes.isEmpty, "Nodes updated")
        #expect(result.totalVelocity > 0, "Velocity calculated")
    }
    
    @Test func testShouldStopSimulation() {
        let simulator = createSimulator()
        let lowVelResult = GraphSimulator.SimulationStepResult(updatedNodes: [], shouldContinue: true, totalVelocity: 0.1)
        #expect(simulator.shouldStopSimulation(result: lowVelResult, nodeCount: 5), "Stops on low velocity")
        
        let highVelResult = GraphSimulator.SimulationStepResult(updatedNodes: [], shouldContinue: true, totalVelocity: 100)
        #expect(!simulator.shouldStopSimulation(result: highVelResult, nodeCount: 5), "Continues on high velocity")
        
        simulator.recentVelocities = [100, 100, 100, 100, 100]  // Stable around high velocity; after append/shift, still stable
        #expect(simulator.shouldStopSimulation(result: highVelResult, nodeCount: 5), "Stops on stable velocities")
    }
    
    @MainActor @Test(.timeLimit(.minutes(1)))
    func testStopSimulation() async {
        let simulator = createSimulator(withEdges: true, forTesting: true)
        await simulator.startSimulation()
        #expect(simulator.simulationTask != nil, "Task running")
        await simulator.stopSimulation()
        #expect(simulator.simulationTask == nil, "Task stopped")
    }
    
    @Test(.timeLimit(.minutes(1)))  // 60s headroom
    func testOnStableCallback() async {
        // Track if onStable was called naturally
        var callbackCalled = false

        // Use createSimulator with nodeCount >=5, edges, and onStable callback
        let simulator = createSimulator(nodeCount: 10, withVisible: true, withEdges: true, forTesting: true, onStable: {
            callbackCalled = true
            print("onStable called naturally after stabilization")  // Debug
        })

        do {
            try await withTimeout(seconds: 10) {
                await simulator.startSimulation()
            }
        } catch {
            print("Simulation timed out or error: \(error)")  // Debug
            await simulator.stopSimulation()
        }

        // Assertions
        #expect(callbackCalled, "onStable should be called after stabilization")
        #expect(simulator.getNodes().allSatisfy { hypot($0.velocity.x, $0.velocity.y) < 0.1 }, "Nodes should have near-zero velocity after stabilization")
    }

    // Helper function for timeout (add this to the test file if not present)
    func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw CancellationError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    struct TimeoutError: Error {}  // Define if not already present
    
    struct GraphModelSimulationTests {
        @MainActor func createModel() -> GraphModel {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            return GraphModel(storage: storage, physicsEngine: physicsEngine)
        }
        
        @MainActor @Test func testResizeSimulationBounds() async {
            let model = createModel()
            model.nodes = (1...10).map { AnyNode(Node(label: $0, position: .zero)) }
            await model.resizeSimulationBounds(for: 10)
            #expect(model.physicsEngine.simulationBounds.width >= 300, "Bounds resized")
        }
        
        @MainActor @Test func testStartSimulation() async {
            let model = createModel()
            let helper = GraphSimulatorTests()
            model.simulator = helper.createSimulator()
            await model.startSimulation()
            #expect(model.isSimulating == false, "Simulation flag reset after start")
            #expect(model.isStable == false, "Stable reset")
        }
        
        @MainActor @Test(.timeLimit(.minutes(1)))
        func testStopSimulation() async {
            let model = createModel()
            let helper = GraphSimulatorTests()
            model.simulator = helper.createSimulator()
            await model.startSimulation()
            await model.stopSimulation()
            #expect(model.simulator.simulationTask == nil, "Simulation stopped")
        }
        
        @MainActor @Test(.timeLimit(.minutes(1)))
        func testPauseAndResumeSimulation() async {
            let model = createModel()
            let helper = GraphSimulatorTests()
            model.simulator = helper.createSimulator(forTesting: true)  // Use test subclass
            await model.pauseSimulation()
            #expect(model.physicsEngine.isPaused == true, "Paused")
            
            await model.resumeSimulation()
            #expect(model.physicsEngine.isPaused == false, "Resumed")
            #expect(model.simulator.simulationTask != nil, "Task running after resume")
        }
    }
    
    struct CoordinateTransformerTests {
        
        @Test func testModelToScreen() {
            let modelPos = CGPoint(x: 10, y: 20)
            let centroid = CGPoint.zero
            let zoom = CGFloat(2.0)
            let offset = CGSize(width: 5, height: 10)
            let viewSize = CGSize(width: 100, height: 100)
            
            let screenPos = CoordinateTransformer.modelToScreen(modelPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
            #expect(screenPos == CGPoint(x: 50 + 20 + 5, y: 50 + 40 + 10), "Correct transformation")
        }
        
        @Test func testScreenToModel() {
            let screenPos = CGPoint(x: 75, y: 100)
            let centroid = CGPoint.zero
            let zoom = CGFloat(2.0)
            let offset = CGSize(width: 5, height: 10)
            let viewSize = CGSize(width: 100, height: 100)
            
            let modelPos = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: centroid, zoomScale: zoom, offset: offset, viewSize: viewSize)
            #expect(modelPos == CGPoint(x: 10, y: 20), "Inverse transformation (rounded)")
        }
        
        @Test func testRoundingInScreenToModel() {
            let screenPos = CGPoint(x: 50.123, y: 50.456)
            let modelPos = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: .zero, zoomScale: 1.0, offset: .zero, viewSize: CGSize(width: 100, height: 100))
            #expect(modelPos.x == 0.123, "Rounded to 3 decimals")
            #expect(modelPos.y == 0.456, "Rounded to 3 decimals")
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
}
