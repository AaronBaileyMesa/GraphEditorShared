//
//  QuadtreeTests.swift
//  GraphEditorShared
//
//  Created by handcart on 9/25/25.
//

import Testing
import Foundation  // For UUID, JSONEncoder, JSONDecoder
import CoreGraphics  // For CGPoint
@testable import GraphEditorShared

func approximatelyEqual(_ lhs: CGPoint, _ rhs: CGPoint, accuracy: CGFloat) -> Bool {
    return hypot(lhs.x - rhs.x, lhs.y - rhs.y) < accuracy
}

struct QuadtreeTests {
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
        for iteration in 0..<10 {
            quadtree.insert(Node(id: UUID(), label: iteration, position: CGPoint(x: 1, y: 1)))
        }
        #expect(quadtree.children != nil, "Initial subdivision occurs")
        #expect(quadtree.totalMass == 10, "Total mass should be 10")
    }
}
