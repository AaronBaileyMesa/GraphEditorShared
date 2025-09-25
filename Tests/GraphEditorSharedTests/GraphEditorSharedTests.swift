import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

// Assuming MockGraphStorage is now in NodeAndEdgeTests.swift; import or duplicate if needed.

struct CGPointAndSizeTests {
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
    
    @Test func testCGPointMagnitudeEdgeCases() {
        let zeroPoint = CGPoint.zero
        #expect(zeroPoint.magnitude == 0, "Zero point magnitude should be 0")
        
        let negativePoint = CGPoint(x: -3, y: -4)
        #expect(negativePoint.magnitude == 5, "Magnitude should be positive for negative coordinates")
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
    
    @Test func testCGPointDivisionAndZeroMagnitude() {
        let point = CGPoint(x: 10, y: 20)
        #expect(point / 2 == CGPoint(x: 5, y: 10), "Division should work")
        
        let zeroPoint = CGPoint.zero
        #expect(zeroPoint.magnitude == 0, "Zero magnitude confirmed")
        #expect(zeroPoint / 1 == .zero, "Division of zero point should remain zero")
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
}

struct ClampingAndMiscTests {
    @Test func testCGFloatClamping() {
        let value: CGFloat = 15
        let clamped = value.clamped(to: 0...10)
        #expect(clamped == 10, "Value should clamp to upper bound")
        
        let lowValue: CGFloat = -5
        let clampedLow = lowValue.clamped(to: 0...10)
        #expect(clampedLow == 0, "Value should clamp to lower bound")
    }
    
    @Test func testDoubleClamping() {
        let value: Double = 15
        let clamped = value.clamped(to: 0...10)
        #expect(clamped == 10, "Double should clamp to upper bound")
        
        let lowValue: Double = -5
        let clampedLow = lowValue.clamped(to: 0...10)
        #expect(clampedLow == 0, "Double should clamp to lower bound")
    }
    
    @Test func testDoubleAndCGFloatClampingEdgeCases() {
        let doubleMax: Double = .greatestFiniteMagnitude
        #expect(doubleMax.clamped(to: 0...1) == 1, "Clamps max value")
        
        let cgfloatMin: CGFloat = -.greatestFiniteMagnitude
        #expect(cgfloatMin.clamped(to: 0...1) == 0, "Clamps min value")
    }
    
    @Test func testGraphStateInitialization() {
        let nodes: [any NodeProtocol] = [Node(id: UUID(), label: 1, position: .zero)]
        let edges = [GraphEdge(from: UUID(), target: UUID())]
        let state = GraphState(nodes: nodes, edges: edges)
        #expect(state.nodes.map { $0.id } == nodes.map { $0.id }, "Nodes should match")
        #expect(state.edges == edges, "Edges should match")
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
        let radius = node1.radius  // Or hardcode if known
        #expect(box.minX == -radius && box.minY == -radius && box.maxX == 100 + radius && box.maxY == 100 + radius, "Bounding box should encompass all nodes")
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
       
    // Tests for GraphModel+Undo.swift
    @MainActor @Test func testSnapshotLimitsUndoStackAndClearsRedo() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        model.maxUndo = 2  // Set low for testing
        model.nodes = [AnyNode(Node(id: UUID(), label: 1, position: .zero))]
        model.edges = [GraphEdge(from: UUID(), target: UUID())]
        
        await model.snapshot()  // Stack: [state1]
        #expect(model.undoStack.count == 1, "Stack appends")
        #expect(model.redoStack.isEmpty, "Redo cleared")
        
        model.nodes.append(AnyNode(Node(id: UUID(), label: 2, position: .zero)))
        await model.snapshot()  // Stack: [state1, state2]
        #expect(model.undoStack.count == 2, "Stack grows")
        
        model.nodes.append(AnyNode(Node(id: UUID(), label: 3, position: .zero)))
        await model.snapshot()  // Stack: [state2, state3] (removes first)
        #expect(model.undoStack.count == 2, "Stack limited")
        #expect(model.undoStack[0].nodes.count == 2, "Oldest removed")
    }
    
    @MainActor @Test func testUndoAndRedoWithEmptyStacks() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        await model.undo()  // Empty stack: no-op
        #expect(model.nodes.isEmpty, "No change on empty undo")
        
        await model.redo()  // Empty stack: no-op
        #expect(model.nodes.isEmpty, "No change on empty redo")
    }
    
    @MainActor @Test func testUndoRedoRoundTrip() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let initialNode = AnyNode(Node(id: UUID(), label: 1, position: .zero))
        model.nodes = [initialNode]
        await model.snapshot()  // Save initial
        
        let newNode = AnyNode(Node(id: UUID(), label: 2, position: .zero))
        model.nodes.append(newNode)
        await model.snapshot()  // Save with 2 nodes
        
        await model.undo()  // Back to 1 node
        #expect(model.nodes.count == 1, "Undo removes node")
        #expect(model.nodes[0].id == initialNode.id, "Initial state restored")
        #expect(model.redoStack.count == 1, "Redo stack populated")
        
        await model.redo()  // Forward to 2 nodes
        #expect(model.nodes.count == 2, "Redo adds node")
        #expect(model.undoStack.count == 2, "Undo stack updated")
    }
    
    @MainActor @Test func testSaveAndLoadViewState() async throws {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let offset = CGPoint(x: 10, y: 20)
        let zoom = CGFloat(1.5)
        let selectedNodeID = UUID()
        let selectedEdgeID = UUID()
        
        try await model.saveViewState(offset: offset, zoomScale: zoom, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID)
        let loaded = try await model.loadViewState()
        #expect(loaded?.offset == offset, "Offset saved/loaded")
        #expect(loaded?.zoomScale == zoom, "Zoom saved/loaded")
        #expect(loaded?.selectedNodeID == selectedNodeID, "Selected node saved/loaded")
        #expect(loaded?.selectedEdgeID == selectedEdgeID, "Selected edge saved/loaded")
    }
  
    // Tests for NodeProtocol.swift
   
    @Test func testNodeProtocolDefaults() {
        let node = Node(id: UUID(), label: 1, position: .zero)
        #expect(node.handlingTap() == node, "Default tap: no change")
        #expect(node.isVisible == true, "Default visible")
        #expect(node.fillColor == .red, "Default color")
        #expect(node.shouldHideChildren() == false, "Default: show children")
    }
    
    @available(iOS 15.0, watchOS 9.0, *)
    @Test func testAnyNodeMutabilityAndCoding() throws {
        let base = ToggleNode(id: UUID(), label: 1, position: .zero, isExpanded: false, content: .string("Test"))
        var anyNode = AnyNode(base)
        anyNode.position = CGPoint(x: 10, y: 20)
        anyNode.content = .number(42.0)
        #expect(anyNode.position == CGPoint(x: 10, y: 20), "Position mutable")
        #expect(anyNode.content == .number(42.0), "Content mutable")
        
        let data = try JSONEncoder().encode(anyNode)
        let decoded = try JSONDecoder().decode(AnyNode.self, from: data)
        #expect(decoded == anyNode, "AnyNode codes round-trip")
        #expect((decoded.unwrapped as? ToggleNode)?.isExpanded == false, "Wrapped type preserved")
    }
    
    @available(iOS 15.0, watchOS 9.0, *)
    @Test func testNodeContentDisplayText() {
        #expect(NodeContent.string("LongStringHere").displayText == "LongString…", "Truncates long string")
        #expect(NodeContent.number(3.14159).displayText == "3.1", "Formats number")
        let date = Date(timeIntervalSince1970: 0)
        #expect(NodeContent.date(date).displayText == "1/1/70", "Formats date consistently")
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
