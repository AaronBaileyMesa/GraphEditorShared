//
//  GraphTypes.swift
//  GraphEditorShared
//
//  Created by handcart on 2025-09-19 13:45:29

import SwiftUI
import Foundation

public typealias NodeID = UUID

@available(iOS 16.0, *)
@available(watchOS 9.0, *)
public struct Node: NodeProtocol, Equatable {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = 10.0
    public var isExpanded: Bool = true  // Satisfy protocol (always true for basic Node)
    public var content: NodeContent?
    public var fillColor: Color { .red }  // Explicit red for basic nodes

    // Init with all params
    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero, radius: CGFloat = 10.0, isExpanded: Bool = true, content: NodeContent? = nil) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = isExpanded
        self.content = content
    }
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        Node(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, content: content)
    }
}


// New: EdgeType enum
public enum EdgeType: String, Codable {
    case hierarchy  // DAG-enforced, directed
    case association  // Allows cycles, symmetric/undirected feel
}

// Represents an edge connecting two nodes.
public struct GraphEdge: Identifiable, Equatable, Codable {
    public let id: NodeID
    public let from: NodeID
    public let target: NodeID
    public let type: EdgeType  // Required type
    
    enum CodingKeys: String, CodingKey {
        case id, from, target, type
    }
    
    public init(id: NodeID = NodeID(), from: NodeID, target: NodeID, type: EdgeType = .association) {
        self.id = id
        self.from = from
        self.target = target
        self.type = type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        from = try container.decode(NodeID.self, forKey: .from)
        target = try container.decode(NodeID.self, forKey: .target)
        type = try container.decode(EdgeType.self, forKey: .type)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(from, forKey: .from)
        try container.encode(target, forKey: .target)
        try container.encode(type, forKey: .type)
    }
    
    public static func == (lhs: GraphEdge, rhs: GraphEdge) -> Bool {
        lhs.id == rhs.id && lhs.from == rhs.from && lhs.target == rhs.target && lhs.type == rhs.type
    }
}

// Snapshot of the graph state for undo/redo.
@available(iOS 16.0, *)
@available(watchOS 9.0, *)
public struct GraphState {
    public let nodes: [any NodeProtocol]
    public let edges: [GraphEdge]
    
    public init(nodes: [any NodeProtocol], edges: [GraphEdge]) {
        self.nodes = nodes
        self.edges = edges
    }
}

@available(iOS 16.0, *)
@available(watchOS 9.0, *)
public enum NodeWrapper: Codable {
    case node(Node)
    case toggleNode(ToggleNode)
    
    enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "node":
            let data = try container.decode(Node.self, forKey: .data)
            self = .node(data)
        case "toggleNode":
            let data = try container.decode(ToggleNode.self, forKey: .data)
            self = .toggleNode(data)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown node type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .node(let node):
            try container.encode("node", forKey: .type)
            try container.encode(node, forKey: .data)
        case .toggleNode(let toggleNode):
            try container.encode("toggleNode", forKey: .type)
            try container.encode(toggleNode, forKey: .data)
        }
    }
    
    public var value: any NodeProtocol {
        switch self {
        case .node(let node): return node
        case .toggleNode(let toggleNode): return toggleNode
        }
    }
}
