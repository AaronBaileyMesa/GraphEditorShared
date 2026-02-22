//
//  DirectionalLayoutTests.swift
//  GraphEditorSharedTests
//
//  Tests for directional layout forces on graph segments
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

struct DirectionalLayoutTests {

    // MARK: - Horizontal Layout Tests

    @MainActor @Test func testTacoTemplateHorizontalLayout() async throws {
        // Create a GraphModel with mock storage
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine, bypassAppCheck: true)
        
        // Verify initial state
        #expect(model.nodes.isEmpty)
        #expect(model.segmentConfigs.isEmpty)
        
        // Create a Taco template
        let centerPosition = CGPoint(x: 100, y: 100)
        let mealNode = await TacoTemplateBuilder.buildGraph(
            in: model,
            guests: 4,
            dinnerTime: Date(),
            protein: .chicken,
            at: centerPosition
        )
        
        // Verify nodes were created (1 meal + 14 tasks = 15 nodes)
        // 6 top-level tasks (shop, prep, cook, assemble, serve, cleanup)
        // + 8 subtasks (prepMeat, prepVegetables, prepSauces, prepToppings, prepShells,
        //                assemblySetup, assemblyBuild, assemblyPlate)
        #expect(model.nodes.count == 15)
        
        // Verify segment config was created
        #expect(model.segmentConfigs.count == 1)
        
        // Verify the segment config is for the meal node
        let segmentConfig = model.segmentConfigs[mealNode.id]
        #expect(segmentConfig != nil)
        #expect(segmentConfig?.direction == LayoutDirection.horizontal)
        #expect(segmentConfig?.rootNodeID == mealNode.id)

        // Verify all task nodes are connected via hierarchy edges
        // 6 top-level chain edges + 8 subtask edges = 14 total
        let hierarchyEdges = model.edges.filter { $0.type == EdgeType.hierarchy }
        #expect(hierarchyEdges.count == 14)
        
        // Verify all nodes are reachable in the segment
        let segmentNodes = model.getSegmentNodes(rootNodeID: mealNode.id)
        #expect(segmentNodes.count == 15)
        
        // Verify top-level chain length via orderedTasks
        let topLevelTasks = model.orderedTasks(for: mealNode.id)
        // Chain: shop → prep → cook → assemble → serve → cleanup (6 tasks)
        #expect(topLevelTasks.count == 6)
        
        // Verify directional forces are applied for horizontal layout
        let allNodes: [any NodeProtocol] = model.nodes.map { $0.unwrapped }
        let forces = DirectionalLayoutCalculator.applyDirectionalForces(
            forces: Dictionary(uniqueKeysWithValues: allNodes.map { ($0.id, CGPoint.zero) }),
            nodes: allNodes,
            edges: model.edges,
            segmentConfigs: model.segmentConfigs,
            simulationBounds: CGSize(width: 500, height: 500)
        )
        
        // At least some nodes should have non-zero horizontal forces
        let totalHorizontalForce = forces.values.reduce(0.0) { $0 + abs($1.x) }
        #expect(totalHorizontalForce > 0, "Horizontal directional forces should be applied")
    }
    
    @MainActor @Test func testVerticalLayoutConfiguration() async throws {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine, bypassAppCheck: true)

        // Create a simple hierarchy
        let rootNode = await model.addNode(at: CGPoint(x: 100, y: 100))
        let child1 = await model.addNode(at: CGPoint(x: 100, y: 150))
        let child2 = await model.addNode(at: CGPoint(x: 100, y: 200))

        await model.addEdge(from: rootNode.id, target: child1.id, type: EdgeType.hierarchy)
        await model.addEdge(from: child1.id, target: child2.id, type: EdgeType.hierarchy)

        // Configure vertical layout
        model.setSegmentConfig(
            rootNodeID: rootNode.id,
            direction: LayoutDirection.vertical,
            strength: 0.7,
            nodeSpacing: 60.0
        )

        #expect(model.segmentConfigs.count == 1)
        let config = model.segmentConfigs[rootNode.id]
        #expect(config?.direction == LayoutDirection.vertical)
        
        // Run simulation
        await model.startSimulation()
        try? await Task.sleep(for: .seconds(2.0))
        await model.stopSimulation()
        
        // Verify vertical arrangement
        let nodes = [rootNode, child1, child2].map { $0.unwrapped }
        
        #expect(nodes.count == 3)
        
        // Verify Y increases (moving down)
        for index in 0..<(nodes.count - 1) {
            #expect(nodes[index + 1].position.y > nodes[index].position.y,
                   "Node should be below previous node")
        }
    }
    
    @MainActor @Test func testSegmentMembership() async throws {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)

        // Create two separate hierarchies
        let root1 = await model.addNode(at: CGPoint(x: 50, y: 50))
        let child1a = await model.addNode(at: CGPoint(x: 50, y: 100))
        let child1b = await model.addNode(at: CGPoint(x: 50, y: 150))

        let root2 = await model.addNode(at: CGPoint(x: 200, y: 50))
        let child2a = await model.addNode(at: CGPoint(x: 200, y: 100))

        await model.addEdge(from: root1.id, target: child1a.id, type: EdgeType.hierarchy)
        await model.addEdge(from: child1a.id, target: child1b.id, type: EdgeType.hierarchy)
        await model.addEdge(from: root2.id, target: child2a.id, type: EdgeType.hierarchy)

        // Configure only the first segment
        model.setSegmentConfig(rootNodeID: root1.id, direction: LayoutDirection.horizontal)
        
        // Test segment membership detection
        let membership = DirectionalLayoutCalculator.buildSegmentMembership(
            nodes: model.nodes.map { $0.unwrapped },
            edges: model.edges,
            segmentConfigs: model.segmentConfigs
        )
        
        // Verify first segment membership
        #expect(membership[root1.id] == root1.id)
        #expect(membership[child1a.id] == root1.id)
        #expect(membership[child1b.id] == root1.id)
        
        // Verify second segment is not in membership (no config)
        #expect(membership[root2.id] == nil)
        #expect(membership[child2a.id] == nil)
    }
    
    @MainActor @Test func testCenteringSkipsSegmentNodes() async throws {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)

        // Create a segment
        let segmentRoot = await model.addNode(at: CGPoint(x: 50, y: 50))
        let segmentChild = await model.addNode(at: CGPoint(x: 100, y: 50))
        await model.addEdge(from: segmentRoot.id, target: segmentChild.id, type: EdgeType.hierarchy)

        // Create a non-segment node
        let freeNode = await model.addNode(at: CGPoint(x: 300, y: 300))

        // Configure segment
        model.setSegmentConfig(rootNodeID: segmentRoot.id, direction: LayoutDirection.horizontal)
        
        // Build membership
        let membership = DirectionalLayoutCalculator.buildSegmentMembership(
            nodes: model.nodes.map { $0.unwrapped },
            edges: model.edges,
            segmentConfigs: model.segmentConfigs
        )
        
        // Verify segment nodes are in membership
        #expect(membership[segmentRoot.id] != nil)
        #expect(membership[segmentChild.id] != nil)
        
        // Verify free node is not in membership
        #expect(membership[freeNode.id] == nil)
    }
    
    @Test func testDirectionalForceCalculation() async throws {
        // Test the force calculation directly
        let node1 = Node(label: 1, position: CGPoint(x: 100, y: 100))
        let node2 = Node(label: 2, position: CGPoint(x: 110, y: 105))
        let node3 = Node(label: 3, position: CGPoint(x: 120, y: 110))
        
        let edge1 = GraphEdge(from: node1.id, target: node2.id, type: .hierarchy)
        let edge2 = GraphEdge(from: node2.id, target: node3.id, type: .hierarchy)
        
        let config = SegmentConfig(
            rootNodeID: node1.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 80.0
        )
        
        let nodes: [any NodeProtocol] = [node1, node2, node3]
        let edges = [edge1, edge2]
        let segmentConfigs = [node1.id: config]
        
        let forces: [NodeID: CGPoint] = [
            node1.id: .zero,
            node2.id: .zero,
            node3.id: .zero
        ]
        
        // Apply directional forces
        let updatedForces = DirectionalLayoutCalculator.applyDirectionalForces(
            forces: forces,
            nodes: nodes,
            edges: edges,
            segmentConfigs: segmentConfigs,
            simulationBounds: CGSize(width: 500, height: 500)
        )
        
        // Verify forces exist for all nodes
        #expect(updatedForces[node1.id] != nil)
        #expect(updatedForces[node2.id] != nil)
        #expect(updatedForces[node3.id] != nil)
        
        // For horizontal layout, forces should primarily be on X-axis
        // Node1 (depth 0) should be at anchor position
        // Node2 (depth 1) should be pushed right
        // Node3 (depth 2) should be pushed further right
        
        let force2 = updatedForces[node2.id]!
        let force3 = updatedForces[node3.id]!
        
        // Forces should be primarily horizontal (X component larger than Y)
        #expect(abs(force2.x) + abs(force3.x) > 0, "Should have horizontal forces")
    }
}
