//
//  GraphSimulatorTests.swift
//  GraphEditorShared
//
//  Created by Handcart on 9/26/2025.
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
            print("Starting simulation with nodeCount: \(await getNodes().count)")  // Added await
    #if os(watchOS)
            // Optionally remove this entire block if not testing watchOS:
            // guard WKApplication.shared().applicationState == .active else { return }
    #endif
            physicsEngine.resetSimulation()
            self.recentVelocities.removeAll()
            
            let nodeCount = await getNodes().count  // Added await
            if nodeCount < 5 {
                onStable?()  // Call here for low count (stable by default)
                let _ = await getNodes()  // Dummy await to ensure async operation
                return
            }
            
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
                self.simulationTask = nil  // Clear after completion
            }
        }
        
        // Add override to slow down for testing
        override func runSimulationLoop(baseInterval: TimeInterval, nodeCount: Int) async {
            print("Starting sim loop with nodeCount: \(nodeCount), maxIterations: 500")
            var iterations = 0
            let maxIterations = 500
            while !Task.isCancelled && iterations < maxIterations {
                let shouldContinue = await performSimulationStep(baseInterval: baseInterval, nodeCount: nodeCount)
                physicsEngine.alpha *= (1 - Constants.Physics.alphaDecay)  // New: Decay alpha
                iterations += 1
                print("Iteration \(iterations): shouldContinue = \(shouldContinue)")
                try? await Task.sleep(for: .milliseconds(20))  // Added: Slow down loop for test reliability
                if !shouldContinue {
                    print("Simulation stabilized after \(iterations) iterations")
                    break
                }
            }
            if iterations >= maxIterations {
                print("Simulation timed out after \(iterations) iterations; recent velocities: \(recentVelocities)")
            }
            self.onStable?()
        }
        
        // NEW: Override to bypass app state check in tests
        override func performSimulationStep(baseInterval: TimeInterval, nodeCount: Int) async -> Bool {
            // Removed #if os(watchOS) guard for WKApplication state to allow simulation in unit tests
            if await physicsEngine.isPaused { return false }
            
            let result = await computeSimulationStep()  // Changed to synchronous call for test reliability
            
            print("Step: Total velocity = \(result.totalVelocity)")
            await self.setNodes(result.updatedNodes)
            
            recentVelocities.append(result.totalVelocity)
            if recentVelocities.count > velocityHistoryCount {
                recentVelocities.removeFirst()
            }
            
            return result.shouldContinue
        }
    }
    
    public func createSimulator(nodeCount: Int = 5, withVisible: Bool = true, withEdges: Bool = false, physicsEngine: PhysicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 3000, height: 3000)), forTesting: Bool = false, onStable: (() -> Void)? = nil) -> GraphSimulator {
        let bounds = physicsEngine.simulationBounds
        let range: CGFloat = 500  // Smaller range for better initial spacing
        var nodes: [any NodeProtocol] = (1...nodeCount).map { Node(label: $0, position: CGPoint(x: CGFloat.random(in: 0...range), y: CGFloat.random(in: 0...range))) }
        var edges: [GraphEdge] = []
        if withEdges {
            edges = (0..<nodeCount-1).map { GraphEdge(from: nodes[$0].id, target: nodes[$0+1].id) }
        }
        
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
                onStable: onStable
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
        if let task = simulator.simulationTask {
            await task.value
        }
        await simulator.stopSimulation()
    }
    
    @MainActor @Test func testVisibleVsAllNodes() async {
        let simulator = createSimulator(nodeCount: 10, withVisible: false, withEdges: true, forTesting: true)
        await simulator.startSimulation()
        #expect(simulator.simulationTask != nil, "Starts with all nodes even if not visible")
        if let task = simulator.simulationTask {
            await task.value
        }
    }
    
    @MainActor @Test func testSimulationWithNoEdges() async {
        let simulator = createSimulator(nodeCount: 10, withEdges: false, forTesting: true)
        await simulator.startSimulation()
        #expect(simulator.simulationTask != nil, "Task started")
        if let task = simulator.simulationTask {
            await task.value
        }
    }
    
    @MainActor @Test func testStartSimulation() async {
        let model = createModel(nodeCount: 4, withEdges: false)
        
        // Override with TestGraphSimulator to bypass watchOS guard
        model.simulator = TestGraphSimulator(
            getNodes: { model.nodes.map { $0.unwrapped } },
            setNodes: { newNodes in model.nodes = newNodes.map { AnyNode($0) } },
            getEdges: { model.edges },
            getVisibleNodes: { model.visibleNodes() },
            getVisibleEdges: { model.visibleEdges() },
            physicsEngine: model.physicsEngine,
            onStable: {
                model.isStable = true
                model.isSimulating = false  // Added: Reset simulating flag as in full model
            }
        )
        
        await model.startSimulation()
        do {
            try await Task.sleep(for: .milliseconds(10))  // Allow time for async onStable to execute
        } catch {}
        #expect(model.isSimulating == false, "Simulation flag reset after start")
        #expect(model.isStable == true, "Stable set for low count")
    }
    
    @MainActor @Test(.timeLimit(.minutes(1)))
    func testPauseAndResumeSimulation() async {
        let model = createModel(nodeCount: 100, withEdges: true)  // Increased for longer runtime
        model.simulator = createSimulator(nodeCount: 100, withEdges: true, physicsEngine: model.physicsEngine, forTesting: true)
        await model.startSimulation()
        do {
            try await Task.sleep(for: .seconds(0.2))  // Increased to ensure simulation is ongoing
        } catch {}
        await model.pauseSimulation()
        do {
            try await Task.sleep(for: .milliseconds(50))  // Small delay for memory sync
        } catch {}
        #expect(model.physicsEngine.isPaused == true, "Paused")
        
        await model.resumeSimulation()
        #expect(model.physicsEngine.isPaused == false, "Resumed")
        #expect(model.simulator.simulationTask != nil, "Task running after resume")
        if let task = model.simulator.simulationTask {
            await task.value
        }
        await model.stopSimulation()
    }
    
    @MainActor func createModel(nodeCount: Int = 5, withEdges: Bool = false) -> GraphModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        let bounds = physicsEngine.simulationBounds
        let range: CGFloat = 300  // Match bounds for spread
        let nodesToAssign = (1...nodeCount).map { Node(label: $0, position: CGPoint(x: CGFloat.random(in: 0...range), y: CGFloat.random(in: 0...range))) }
        model.nodes = nodesToAssign.map(AnyNode.init)
        
        if withEdges {
            model.edges = (0..<nodeCount-1).map { GraphEdge(from: nodesToAssign[$0].id, target: nodesToAssign[$0+1].id) }
        }
        
        return model
    }
    
    @MainActor @Test func testStopSimulation() async {
        let simulator = createSimulator(nodeCount: 10, withEdges: true, forTesting: true)
        await simulator.startSimulation()
        #expect(simulator.simulationTask != nil, "Task started")
        await simulator.stopSimulation()
        #expect(simulator.simulationTask == nil, "Task cleared after stop")
    }
    
    @MainActor @Test func testRunSimulationLoop() async {
        let simulator = createSimulator(nodeCount: 10, withEdges: true, forTesting: true)
        let interval = 1.0 / 60.0
        await simulator.runSimulationLoop(baseInterval: interval, nodeCount: 10)
        #expect(simulator.recentVelocities.last ?? 100 < 0.1, "Velocities low after loop")
    }
    
    @MainActor @Test func testPerformSimulationStep() async {
        let simulator = createSimulator(nodeCount: 5, withEdges: true, forTesting: true)
        let shouldContinue = await simulator.performSimulationStep(baseInterval: 1.0 / 60.0, nodeCount: 5)
        #expect(shouldContinue == true, "Should continue if not stable")
    }
    
    @MainActor @Test func testComputeSimulationStep() async {
        let simulator = createSimulator(nodeCount: 5, withEdges: true, forTesting: true)
        let result = await simulator.computeSimulationStep()
        #expect(result.shouldContinue == true, "Should continue if not stable")
        #expect(result.totalVelocity > 0, "Initial velocity")
        #expect(result.updatedNodes.count == 5, "All nodes updated")
    }
    
    @MainActor func createModel() -> GraphModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return model
    }
    
    @MainActor @Test(.timeLimit(.minutes(1)))
    func testStopModelSimulation() async {
        let model = createModel()
        let helper = GraphSimulatorTests()
        model.simulator = helper.createSimulator()
        await model.startSimulation()
        await model.stopSimulation()
        #expect(model.simulator.simulationTask == nil, "Simulation stopped")
    }
}
struct CoordinateTransformerTests {
    @Test func testModelToScreen() {
        let modelPos = CGPoint(x: 20, y: 40)
        let centroid = CGPoint.zero
        let zoom = CGFloat(1.0)
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
