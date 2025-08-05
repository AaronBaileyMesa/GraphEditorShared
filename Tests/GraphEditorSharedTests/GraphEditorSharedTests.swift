import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
import GraphEditorShared

struct GraphEditorSharedTests {
    
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
        let to = UUID()
        let edge1 = GraphEdge(id: id, from: from, to: to)
        let edge2 = GraphEdge(id: id, from: from, to: to)
        #expect(edge1 == edge2, "Edges with same properties should be equal")
        
        let edge3 = GraphEdge(from: to, to: from)
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
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 3, y: 4)
        #expect(distance(a, b) == 5, "Distance should be calculated correctly")
    }
    
    @Test func testGraphStateInitialization() {
        let nodes = [Node(id: UUID(), label: 1, position: .zero)]
        let edges = [GraphEdge(from: UUID(), to: UUID())]
        let state = GraphState(nodes: nodes, edges: edges)
        #expect(state.nodes == nodes, "Nodes should match")
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
        let edge = GraphEdge(id: UUID(), from: UUID(), to: UUID())
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
    
    @Test func testGraphStateCoding() throws {
        let state = GraphState(nodes: [Node(id: UUID(), label: 1, position: .zero)], edges: [GraphEdge(from: UUID(), to: UUID())])
        let encoder = JSONEncoder()
        let data = try encoder.encode(state)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GraphState.self, from: data)
        #expect(state.nodes == decoded.nodes, "GraphState nodes should match after coding")
        #expect(state.edges == decoded.edges, "GraphState edges should match after coding")
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
        let edge = GraphEdge(from: UUID(), to: UUID())
        #expect(edge.from != edge.to, "Directed edge has distinct from/to")
    }
    
    @Test func testAsymmetricAttraction() throws {
        let engine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        engine.useAsymmetricAttraction = true
        var nodes = [Node(id: UUID(), label: 1, position: CGPoint(x: 0, y: 0)),
                     Node(id: UUID(), label: 2, position: CGPoint(x: 200, y: 0))]
        let edges = [GraphEdge(from: nodes[0].id, to: nodes[1].id)]
        _ = engine.simulationStep(nodes: &nodes, edges: edges)
        #expect(abs(nodes[0].position.x - 0) < 1, "From node position unchanged in asymmetric")
        #expect(nodes[1].position.x < 200, "To node pulled towards from")
    }
}

struct PerformanceTests {

    @available(watchOS 9.0, *)  // Guard for availability
    @Test func testSimulationPerformance() {
        let engine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        var nodes: [Node] = (1...100).map { Node(label: $0, position: CGPoint(x: CGFloat.random(in: 0...300), y: CGFloat.random(in: 0...300))) }
        let edges: [GraphEdge] = []

        let start = Date()
        for _ in 0..<10 {
            _ = engine.simulationStep(nodes: &nodes, edges: edges)
        }
        let duration = Date().timeIntervalSince(start)

        print("Duration for 10 simulation steps with 100 nodes: \(duration) seconds")

        #expect(duration < 0.5, "Simulation should be performant")
    }
    
}
