import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

class MockGraphStorage: GraphStorage {
    var nodes: [any NodeProtocol] = []
    var edges: [GraphEdge] = []
    
    func save(nodes: [any NodeProtocol], edges: [GraphEdge]) throws {
        self.nodes = nodes
        self.edges = edges
    }
    
    func load() throws -> (nodes: [any NodeProtocol], edges: [GraphEdge]) {
        (nodes, edges)
    }
    
    func clear() throws {
        nodes = []
        edges = []
    }
}

func approximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint, accuracy: CGFloat) -> Bool {
    return hypot(lhs.x - rhs.x, lhs.y - rhs.y) < accuracy
}

struct GraphEditorSharedTests {
    @Test func testQuadtreeInitialization() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let quadtree = Quadtree(bounds: bounds)
        #expect(quadtree.children == nil, "Children should be nil initially")
        #expect(quadtree.totalMass == 0, "Total mass should be zero initially")
        #expect(quadtree.centerOfMass == .zero, "Center of mass should be zero initially")
    }

    @Test func testQuadtreeSingleInsert() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let quadtree = Quadtree(bounds: bounds)
        let node = Node(id: UUID(), label: 1, position: CGPoint(x: 10, y: 20))
        quadtree.insert(node)
        #expect(quadtree.totalMass == 1, "Total mass should be 1")
        #expect(quadtree.centerOfMass == node.position, "Center of mass should match node position")
    }

    @Test func testQuadtreeSubdivisionOnMultipleInserts() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let quadtree = Quadtree(bounds: bounds)
        let node1 = Node(id: UUID(), label: 1, position: CGPoint(x: 10, y: 10))  // SW
        let node2 = Node(id: UUID(), label: 2, position: CGPoint(x: 60, y: 60))  // NE
        quadtree.insert(node1)
        quadtree.insert(node2)
        #expect(quadtree.children != nil, "Should subdivide after multiple inserts")
        #expect(quadtree.children?[0].totalMass == 1, "SW child should have mass 1")
        #expect(quadtree.children?[3].totalMass == 1, "NE child should have mass 1")
        #expect(quadtree.totalMass == 2, "Total mass should be 2")
        let expectedCOM = (node1.position + node2.position) / 2
        #expect(quadtree.centerOfMass == expectedCOM, "Center of mass should be average")
    }

    @Test func testQuadtreeBatchInsert() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let quadtree = Quadtree(bounds: bounds)
        let node1 = Node(id: UUID(), label: 1, position: CGPoint(x: 10, y: 10))  // SW
        let node2 = Node(id: UUID(), label: 2, position: CGPoint(x: 60, y: 60))  // NE
        let node3 = Node(id: UUID(), label: 3, position: CGPoint(x: 10, y: 60))  // NW
        let nodes = [node1, node2, node3]
        quadtree.batchInsert(nodes)
        #expect(quadtree.totalMass == 3, "Total mass should be 3")
        #expect(quadtree.children != nil, "Should subdivide")
        #expect(quadtree.children?[0].totalMass == 1, "SW should have mass 1")
        #expect(quadtree.children?[2].totalMass == 1, "NW should have mass 1")
        #expect(quadtree.children?[3].totalMass == 1, "NE should have mass 1")
        let expectedCOM = (node1.position + node2.position + node3.position) / 3
        #expect(quadtree.centerOfMass == expectedCOM, "Center of mass should be average")
    }

    @Test func testQuadtreeComputeForceLeaf() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let quadtree = Quadtree(bounds: bounds)
        let node1 = Node(id: UUID(), label: 1, position: CGPoint(x: 10, y: 10))
        let node2 = Node(id: UUID(), label: 2, position: CGPoint(x: 20, y: 20))
        quadtree.insert(node1)
        quadtree.insert(node2)
        let force = quadtree.computeForce(on: node1)
        #expect(force.x < 0 && force.y < 0, "Force should repel away from node2")
    }

    @Test func testQuadtreeQueryNearby() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let quadtree = Quadtree(bounds: bounds)
        let node1 = Node(id: UUID(), label: 1, position: CGPoint(x: 10, y: 10))
        let node2 = Node(id: UUID(), label: 2, position: CGPoint(x: 50, y: 50))
        let node3 = Node(id: UUID(), label: 3, position: CGPoint(x: 90, y: 90))
        quadtree.insert(node1)
        quadtree.insert(node2)
        quadtree.insert(node3)
        let nearby = quadtree.queryNearby(position: CGPoint(x: 10, y: 10), radius: 20)
        #expect(nearby.count == 1, "Should find only node1 within radius")
        #expect(nearby[0].id == node1.id, "Found node should be node1")
    }

    @Test func testQuadtreeMaxDepthAndMinSize() {
        let bounds = CGRect(x: 0, y: 0, width: Constants.Physics.minQuadSize * 2, height: Constants.Physics.minQuadSize * 2)
        let quadtree = Quadtree(bounds: bounds)
        for i in 0..<10 {
            quadtree.insert(Node(id: UUID(), label: i, position: CGPoint(x: 1, y: 1)))
        }
        #expect(quadtree.children != nil, "Initial subdivision occurs")
        #expect(quadtree.totalMass == 10, "Total mass should be 10")
    }
    
    
    @Test func testNodeInitializationAndEquality() {
        let id = UUID()
        let node1 = Node(id: id, label: 1, position: CGPoint(x: 10, y: 20))
        let node2 = Node(id: id, label: 1, position: CGPoint(x: 10, y: 20))
        #expect(node1 == node2, "Nodes with same properties should be equal")
        
        let node3 = Node(id: UUID(), label: 2, position: .zero)
        #expect(node1 != node3, "Nodes with different IDs/labels should not be equal")
    }
    
    @Test func testNodeCodingRoundTrip() throws {
        let node = Node(id: UUID(), label: 1, position: CGPoint(x: 5, y: 10), velocity: CGPoint(x: 1, y: 2))
        let encoder = JSONEncoder()
        let data = try encoder.encode(node)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Node.self, from: data)
        #expect(node == decoded, "Node should encode and decode without data loss")
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
    
    @Test func testCGPointExtensions() {
        let point1 = CGPoint(x: 3, y: 4)
        let point2 = CGPoint(x: 1, y: 2)
        
        #expect(point1 + point2 == CGPoint(x: 4, y: 6), "Addition should work")
        #expect(point1 - point2 == CGPoint(x: 2, y: 2), "Subtraction should work")
        #expect(point1 * 2 == CGPoint(x: 6, y: 8), "Scalar multiplication should work")
        #expect(point1.magnitude == 5, "Magnitude should be correct")
    }
    
    @Test func testDistanceFunction() {
        let fromPoint = CGPoint(x: 0, y: 0)
        let targetPoint = CGPoint(x: 3, y: 4)
        #expect(distance(fromPoint, targetPoint) == 5, "Distance should be calculated correctly")
    }
    
    @Test func testGraphStateInitialization() {
        let nodes: [any NodeProtocol] = [Node(id: UUID(), label: 1, position: .zero)]
        let edges = [GraphEdge(from: UUID(), target: UUID())]
        let state = GraphState(nodes: nodes, edges: edges)
        #expect(state.nodes.map { $0.id } == nodes.map { $0.id }, "Nodes should match")
        #expect(state.edges == edges, "Edges should match")
    }
    
    @Test func testCGFloatClamping() {
        let value: CGFloat = 15
        let clamped = value.clamped(to: 0...10)
        #expect(clamped == 10, "Value should clamp to upper bound")
        
        let lowValue: CGFloat = -5
        let clampedLow = lowValue.clamped(to: 0...10)
        #expect(clampedLow == 0, "Value should clamp to lower bound")
    }
    
    @Test func testCGPointMagnitudeEdgeCases() {
        let zeroPoint = CGPoint.zero
        #expect(zeroPoint.magnitude == 0, "Zero point magnitude should be 0")
        
        let negativePoint = CGPoint(x: -3, y: -4)
        #expect(negativePoint.magnitude == 5, "Magnitude should be positive for negative coordinates")
    }
    @Test func testNodeDecodingWithMissingKeys() throws {
        // Test partial data to cover error paths in init(from decoder:)
        let json = "{\"id\": \"\(UUID())\", \"label\": 1}"  // Missing position/velocity
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(Node.self, from: data)
        }
    }
    
    @Test func testGraphEdgeCodingRoundTrip() throws {
        let edge = GraphEdge(id: UUID(), from: UUID(), target: UUID())
        let encoder = JSONEncoder()
        let data = try encoder.encode(edge)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GraphEdge.self, from: data)
        #expect(edge == decoded, "Edge should encode and decode without loss")
    }
    
    @Test func testCGSizeExtensions() {
        let size1 = CGSize(width: 10, height: 20)
        let size2 = CGSize(width: 5, height: 10)
        
        #expect(size1 / 2 == CGSize(width: 5, height: 10), "Division should work")
        #expect(size1 + size2 == CGSize(width: 15, height: 30), "Addition should work")
        
        var mutableSize = size1
        mutableSize += size2
        #expect(mutableSize == CGSize(width: 15, height: 30), "In-place addition should work")
    }
    
    @Test func testDoubleClamping() {
        let value: Double = 15
        let clamped = value.clamped(to: 0...10)
        #expect(clamped == 10, "Double should clamp to upper bound")
        
        let lowValue: Double = -5
        let clampedLow = lowValue.clamped(to: 0...10)
        #expect(clampedLow == 0, "Double should clamp to lower bound")
    }
    
    @Test func testGraphEdgeDecodingWithMissingKeys() throws {
        // Cover error paths in init(from decoder:)
        let json = "{\"id\": \"\(UUID())\", \"from\": \"\(UUID())\"}"  // Missing 'to'
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(GraphEdge.self, from: data)
        }
    }
    
    @Test func testCGPointDivisionAndZeroMagnitude() {
        let point = CGPoint(x: 10, y: 20)
        #expect(point / 2 == CGPoint(x: 5, y: 10), "Division should work")
        
        let zeroPoint = CGPoint.zero
        #expect(zeroPoint.magnitude == 0, "Zero magnitude confirmed")
        #expect(zeroPoint / 1 == .zero, "Division of zero point should remain zero")
    }
    
    @Test func testDoubleAndCGFloatClampingEdgeCases() {
        let doubleMax: Double = .greatestFiniteMagnitude
        #expect(doubleMax.clamped(to: 0...1) == 1, "Clamps max value")
        
        let cgfloatMin: CGFloat = -.greatestFiniteMagnitude
        #expect(cgfloatMin.clamped(to: 0...1) == 0, "Clamps min value")
    }
    
    @Test func testCGPointAllOperators() {
        var point1 = CGPoint(x: 5, y: 10)
        let point2 = CGPoint(x: 3, y: 4)
        let scalar: CGFloat = 2
        
        // Cover + and +=
        #expect(point1 + point2 == CGPoint(x: 8, y: 14), "Addition should work")
        point1 += point2
        #expect(point1 == CGPoint(x: 8, y: 14), "In-place addition should work")
        
        // Cover - and -=
        #expect(point1 - point2 == CGPoint(x: 5, y: 10), "Subtraction should work")
        point1 -= point2
        #expect(point1 == CGPoint(x: 5, y: 10), "In-place subtraction should work")
        
        // Cover * and *=
        #expect(point1 * scalar == CGPoint(x: 10, y: 20), "Multiplication should work")
        point1 *= scalar
        #expect(point1 == CGPoint(x: 10, y: 20), "In-place multiplication should work")
        
        // Cover /
        #expect(point1 / scalar == CGPoint(x: 5, y: 10), "Division should work")
    }
    
    @Test func testCGPointWithSizeOperators() {
        var point = CGPoint(x: 5, y: 10)
        let size = CGSize(width: 3, height: 4)
        
        #expect(point + size == CGPoint(x: 8, y: 14), "Addition with size should work")
        point += size
        #expect(point == CGPoint(x: 8, y: 14), "In-place addition with size should work")
    }
    
    @Test func testCGSizeAllOperators() {
        var size1 = CGSize(width: 10, height: 20)
        let size2 = CGSize(width: 5, height: 10)
        let scalar: CGFloat = 2
        
        // Cover + and +=
        #expect(size1 + size2 == CGSize(width: 15, height: 30), "Addition should work")
        size1 += size2
        #expect(size1 == CGSize(width: 15, height: 30), "In-place addition should work")
        
        // Cover /
        #expect(size1 / scalar == CGSize(width: 7.5, height: 15), "Division should work")
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
    
    @Test func testDistanceEdgeCases() {
        let samePoint = CGPoint(x: 5, y: 5)
        #expect(distance(samePoint, samePoint) == 0, "Distance to self is 0")
        
        let negativePoints = CGPoint(x: -3, y: -4)
        let origin = CGPoint.zero
        #expect(distance(negativePoints, origin) == 5, "Distance with negatives is positive")
    }
    
    @Test func testDirectedEdgeCreation() {
        let edge = GraphEdge(from: UUID(), target: UUID())
        #expect(edge.from != edge.target, "Directed edge has distinct from/to")
    }
    
    @Test func testAsymmetricAttraction() throws {
        let engine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        engine.useAsymmetricAttraction = true  // Assumes this property is added (see implementation below)
        let fromID = UUID()
        let toID = UUID()
        var nodes: [any NodeProtocol] = [Node(id: fromID, label: 1, position: CGPoint(x: 0, y: 0)),
                     Node(id: toID, label: 2, position: CGPoint(x: 200, y: 0))]
        let edges = [GraphEdge(from: fromID, target: toID)]
        let (updatedNodes, _) = engine.simulationStep(nodes: nodes, edges: edges)
        nodes = updatedNodes
        #expect(abs(nodes[0].position.x - 0) < 1, "From node position unchanged in asymmetric")
        #expect(nodes[1].position.x < 200, "To node pulled towards from")
    }
    
    // Tests for GraphModel+Visibility.swift
    // Tests for GraphModel+Visibility.swift

    @MainActor @Test func testVisibleNodesAndEdges() async {
        let storage = MockGraphStorage()
        let parentID = UUID()
        let childID = UUID()
        let otherID = UUID()
        let parent = ToggleNode(id: parentID, label: 1, position: CGPoint.zero, isExpanded: false)
        let child = Node(id: childID, label: 2, position: CGPoint.zero)
        let other = Node(id: otherID, label: 3, position: CGPoint.zero)
        storage.nodes = [parent, child, other]
        storage.edges = [
            GraphEdge(from: parentID, target: childID, type: EdgeType.hierarchy),
            GraphEdge(from: parentID, target: otherID, type: EdgeType.association),
            GraphEdge(from: otherID, target: childID, type: EdgeType.association)
        ]
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        await model.load()  // Calls syncCollapsedPositions internally

        let visibleNodes = model.visibleNodes()
        #expect(visibleNodes.count == 2, "Child should be hidden when parent collapsed")
        #expect(visibleNodes.map { $0.id }.contains(parentID), "Parent visible")
        #expect(visibleNodes.map { $0.id }.contains(otherID), "Other visible")

        let visibleEdges = model.visibleEdges()
        #expect(visibleEdges.count == 1, "Only edge between visible nodes")
        #expect(visibleEdges[0].from == parentID && visibleEdges[0].target == otherID, "Association edge visible")
    }
    
        @MainActor @Test func testBoundingBox() {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            let node1 = Node(id: UUID(), label: 1, position: CGPoint(x: 0, y: 0))
            let node2 = Node(id: UUID(), label: 2, position: CGPoint(x: 100, y: 100))
            model.nodes = [AnyNode(node1), AnyNode(node2)]

            let box = model.boundingBox()
            let r = node1.radius  // Or hardcode if known
            #expect(box.minX == -r && box.minY == -r && box.maxX == 100 + r && box.maxY == 100 + r, "Bounding box should encompass all nodes")
        }

        @MainActor @Test func testCenterGraph() {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 200, height: 200))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            let node1 = Node(id: UUID(), label: 1, position: CGPoint(x: 0, y: 0))
            let node2 = Node(id: UUID(), label: 2, position: CGPoint(x: 100, y: 100))
            model.nodes = [AnyNode(node1), AnyNode(node2)]

            model.centerGraph()
            let centeredNodes = model.nodes.map { $0.position }
            let avgX = (centeredNodes[0].x + centeredNodes[1].x) / 2
            let avgY = (centeredNodes[0].y + centeredNodes[1].y) / 2
            #expect(avgX == 100 && avgY == 100, "Nodes should be centered in bounds")
        }

        @MainActor @Test func testExpandAllRoots() async {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            let root1 = ToggleNode(id: UUID(), label: 1, position: CGPoint.zero, isExpanded: false)
            let root2 = ToggleNode(id: UUID(), label: 2, position: CGPoint.zero, isExpanded: false)
            let child = Node(id: UUID(), label: 3, position: CGPoint.zero)
            model.nodes = [AnyNode(root1), AnyNode(root2), AnyNode(child)]
            model.edges = [GraphEdge(from: root1.id, target: child.id, type: EdgeType.hierarchy)]

            await model.expandAllRoots()
            #expect((model.nodes[0].unwrapped as? ToggleNode)?.isExpanded == true, "Root1 should be expanded")
            #expect((model.nodes[1].unwrapped as? ToggleNode)?.isExpanded == true, "Root2 should be expanded")
        }

        // Tests for GraphModel+EdgesNodes.swift

        @MainActor @Test func testWouldCreateCycle() {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            let node1ID = UUID()
            let node2ID = UUID()
            let node3ID = UUID()
            model.nodes = [
                AnyNode(Node(id: node1ID, label: 1, position: CGPoint.zero)),
                AnyNode(Node(id: node2ID, label: 2, position: CGPoint.zero)),
                AnyNode(Node(id: node3ID, label: 3, position: CGPoint.zero))
            ]
            model.edges = [
                GraphEdge(from: node1ID, target: node2ID, type: EdgeType.hierarchy),
                GraphEdge(from: node2ID, target: node3ID, type: EdgeType.hierarchy)
            ]

            #expect(model.wouldCreateCycle(withNewEdgeFrom: node3ID, target: node1ID, type: EdgeType.hierarchy) == true, "Should detect cycle")
            #expect(model.wouldCreateCycle(withNewEdgeFrom: node1ID, target: node3ID, type: EdgeType.hierarchy) == false, "No cycle")
            #expect(model.wouldCreateCycle(withNewEdgeFrom: node1ID, target: node2ID, type: EdgeType.association) == false, "Non-hierarchy ignores cycle check")
        }

        @MainActor @Test func testAddAndDeleteEdge() async {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            let node1ID = UUID()
            let node2ID = UUID()
            model.nodes = [
                AnyNode(Node(id: node1ID, label: 1, position: CGPoint.zero)),
                AnyNode(Node(id: node2ID, label: 2, position: CGPoint.zero))
            ]

            await model.addEdge(from: node1ID, target: node2ID, type: EdgeType.hierarchy)
            #expect(model.edges.count == 1, "Edge should be added")

            let edgeID = model.edges[0].id
            await model.deleteEdge(withID: edgeID)
            #expect(model.edges.isEmpty, "Edge should be deleted")
        }

        @MainActor @Test func testAddNodeAndAddToggleNode() async {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            model.nextNodeLabel = 1

            await model.addNode(at: CGPoint.zero)
            #expect(model.nodes.count == 1, "Node added")
            #expect(model.nodes[0].unwrapped.label == 1, "Label set correctly")
            #expect(model.nextNodeLabel == 2, "Label incremented")

            await model.addToggleNode(at: CGPoint.zero)
            #expect(model.nodes.count == 2, "ToggleNode added")
            #expect(model.nodes[1].unwrapped.label == 2, "Label set correctly")
            #expect(model.nextNodeLabel == 3, "Label incremented")
        }

        @MainActor @Test func testAddChildAndDeleteNode() async {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            let parentID = UUID()
            model.nodes = [AnyNode(Node(id: parentID, label: 1, position: CGPoint.zero))]
            model.nextNodeLabel = 2

            await model.addChild(to: parentID)
            #expect(model.nodes.count == 2, "Child added")
            #expect(model.edges.count == 1, "Hierarchy edge added")
            #expect(model.edges[0].type == EdgeType.hierarchy, "Correct edge type")
            #expect(model.nextNodeLabel == 3, "Label incremented")

            let childID = model.nodes[1].id
            await model.deleteNode(withID: childID)
            #expect(model.nodes.count == 1, "Child deleted")
            #expect(model.edges.isEmpty, "Edge removed")
        }

    /*
    @MainActor @Test func testUpdateNodeContent() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let nodeID = UUID()
        model.nodes = [AnyNode(Node(id: nodeID, label: 1, position: CGPoint.zero))]

        let json = "{\"text\":\"Test\"}".data(using: .utf8)!
        let newContent = try! JSONDecoder().decode(NodeContent.self, from: json)
        await model.updateNodeContent(withID: nodeID, newContent: newContent)
        #expect(model.nodes[0].unwrapped.content == newContent, "Content updated")
    }*/
    
        // Tests for GraphModel+Storage.swift
        @MainActor @Test func testLoadAndSaveWithMockStorage() async throws {
            let mockStorage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: mockStorage, physicsEngine: physicsEngine)
            let node = Node(id: UUID(), label: 1, position: CGPoint.zero)
            let edge = GraphEdge(from: node.id, target: UUID())
            mockStorage.nodes = [node]
            mockStorage.edges = [edge]

            await model.load()
            #expect(model.nodes.count == 1, "Loaded nodes")
            #expect(model.edges.count == 1, "Loaded edges")
            #expect(model.nextNodeLabel == 2, "Next label set")

            let newNode = Node(id: UUID(), label: 2, position: CGPoint.zero)
            model.nodes.append(AnyNode(newNode))
            await model.save()
            #expect(mockStorage.nodes.count == 2, "Saved nodes")
            #expect(mockStorage.edges.count == 1, "Saved edges")
        }

        @MainActor @Test func testClearGraphWithMockStorage() async throws {
            let mockStorage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: mockStorage, physicsEngine: physicsEngine)
            model.nodes = [AnyNode(Node(id: UUID(), label: 1, position: CGPoint.zero))]
            model.edges = [GraphEdge(from: UUID(), target: UUID())]
            model.nextNodeLabel = 5

            await model.clearGraph()
            #expect(model.nodes.isEmpty, "Nodes cleared")
            #expect(model.edges.isEmpty, "Edges cleared")
            #expect(model.nextNodeLabel == 1, "Label reset")
            #expect(mockStorage.nodes.isEmpty, "Storage cleared")
            #expect(mockStorage.edges.isEmpty, "Storage cleared")
        }

    @MainActor @Test func testSyncCollapsedPositions() async {
        let storage = MockGraphStorage()
        let parentID = UUID()
        let child1ID = UUID()
        let child2ID = UUID()
        let parent = ToggleNode(id: parentID, label: 1, position: CGPoint(x: 100, y: 100), isExpanded: false)
        let child1 = Node(id: child1ID, label: 2, position: CGPoint.zero)
        let child2 = Node(id: child2ID, label: 3, position: CGPoint.zero)
        storage.nodes = [parent, child1, child2]
        storage.edges = [
            GraphEdge(from: parentID, target: child1ID, type: EdgeType.hierarchy),
            GraphEdge(from: parentID, target: child2ID, type: EdgeType.hierarchy)
        ]
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        await model.load()  // Calls syncCollapsedPositions internally
        #expect(approximatelyEqual(model.nodes[1].position, model.nodes[0].position, accuracy: 6), "Child1 close to parent")
        #expect(approximatelyEqual(model.nodes[2].position, model.nodes[0].position, accuracy: 6), "Child2 close to parent")
        #expect(model.nodes[1].velocity == .zero, "Velocity reset")
    }
    
        // Tests for GraphModel+Helpers.swift
        @MainActor @Test func testBuildAdjacencyList() {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            let node1ID = UUID()
            let node2ID = UUID()
            let node3ID = UUID()
            model.nodes = [
                AnyNode(Node(id: node1ID, label: 1, position: CGPoint.zero)),
                AnyNode(Node(id: node2ID, label: 2, position: CGPoint.zero)),
                AnyNode(Node(id: node3ID, label: 3, position: CGPoint.zero))
            ]
            model.edges = [
                GraphEdge(from: node1ID, target: node2ID, type: EdgeType.hierarchy),
                GraphEdge(from: node1ID, target: node3ID, type: EdgeType.association),
                GraphEdge(from: node2ID, target: node3ID, type: EdgeType.hierarchy)
            ]

            let allAdj = model.buildAdjacencyList()
            #expect(allAdj[node1ID]?.count == 2, "All edges from node1")
            #expect(allAdj[node2ID]?.count == 1, "All edges from node2")

            let hierarchyAdj = model.buildAdjacencyList(for: EdgeType.hierarchy)
            #expect(hierarchyAdj[node1ID]?.count == 1, "Only hierarchy from node1")
            #expect(hierarchyAdj[node1ID]?[0] == node2ID, "Correct target")
        }

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

        @MainActor @Test func testHandleTapOnToggleNode() async {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            let parentID = UUID()
            let childID = UUID()
            let parent = ToggleNode(id: parentID, label: 1, position: CGPoint(x: 100, y: 100), isExpanded: false)
            let child = Node(id: childID, label: 2, position: CGPoint.zero)
            model.nodes = [AnyNode(parent), AnyNode(child)]
            model.edges = [GraphEdge(from: parentID, target: childID, type: EdgeType.hierarchy)]

            await model.handleTap(on: parentID)
            let updatedParent = model.nodes[0].unwrapped as? ToggleNode
            #expect(updatedParent?.isExpanded == true, "Toggled to expanded")
            #expect(model.nodes[1].position != CGPoint.zero, "Child position offset")
            #expect(model.nodes[1].velocity == .zero, "Velocity reset")
        }

        @MainActor @Test func testGraphDescription() {
            let storage = MockGraphStorage()
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
            let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
            let node1ID = UUID()
            let node2ID = UUID()
            let node3ID = UUID()
            let edgeID = UUID()
            model.nodes = [
                AnyNode(Node(id: node1ID, label: 1, position: CGPoint.zero)),
                AnyNode(Node(id: node2ID, label: 2, position: CGPoint.zero)),
                AnyNode(Node(id: node3ID, label: 3, position: CGPoint.zero))
            ]
            model.edges = [
                GraphEdge(id: edgeID, from: node1ID, target: node2ID),
                GraphEdge(from: node2ID, target: node3ID),
                GraphEdge(from: node3ID, target: node1ID)
            ]

            let noSelection = model.graphDescription(selectedID: Optional<NodeID>.none, selectedEdgeID: Optional<UUID>.none)
            #expect(noSelection.contains("3 nodes and 3 directed edges"), "Basic description")
            #expect(noSelection.contains("No node or edge selected"), "No selection")

            let nodeSelection = model.graphDescription(selectedID: node1ID, selectedEdgeID: Optional<UUID>.none)
            #expect(nodeSelection.contains("Node 1 selected"), "Node selected")
            #expect(nodeSelection.contains("outgoing to: 2"), "Outgoing")
            #expect(nodeSelection.contains("incoming from: 3"), "Incoming")

            let edgeSelection = model.graphDescription(selectedID: Optional<NodeID>.none, selectedEdgeID: edgeID)
            #expect(edgeSelection.contains("Directed edge from node 1 to node 2 selected"), "Edge selected")
        }
    }

    struct PerformanceTests {

        @available(watchOS 9.0, *)  // Guard for availability
        @Test func testSimulationPerformance() {
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
