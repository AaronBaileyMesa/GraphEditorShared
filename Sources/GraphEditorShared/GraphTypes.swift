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
public struct Node: NodeProtocol, Codable {  // Updated: Conform to NodeProtocol (which now includes HierarchicalNode)
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = 10.0
    public var children: [UUID] = []
    public var isExpanded: Bool = true
    public var contents: [NodeContent] = []
    public var fillColor: Color { .red }

    // Init with all params
    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero, radius: CGFloat = 10.0, isExpanded: Bool = true, contents: [NodeContent] = []) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = isExpanded
        self.contents = contents
    }
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        Node(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents)
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        Node(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents)
    }
    
    public func shouldHideChildren() -> Bool {
            return false  // Explicit for non-hierarchical nodes
        }
    
    // Codable conformance (mirrors ToggleNode for consistency)
    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius, isExpanded, contents, children
    }
     public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? 10.0  // Default if missing
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true  // Default if missing
        contents = try container.decodeIfPresent([NodeContent].self, forKey: .contents) ?? []  // Default if missing
        children = try container.decodeIfPresent([NodeID].self, forKey: .children) ?? []  // Default if missing
        let posX = try container.decode(CGFloat.self, forKey: .positionX)  // Required
        let posY = try container.decode(CGFloat.self, forKey: .positionY)  // Required
        position = CGPoint(x: posX, y: posY)
        let velX = try container.decodeIfPresent(CGFloat.self, forKey: .velocityX) ?? 0.0  // Default to 0 if missing
        let velY = try container.decodeIfPresent(CGFloat.self, forKey: .velocityY) ?? 0.0  // Default to 0 if missing
        velocity = CGPoint(x: velX, y: velY)
    }
     public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(radius, forKey: .radius)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(contents, forKey: .contents)
        try container.encode(children, forKey: .children)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
    }
}

// Extension for methods only (no stored props)
extension Node {
    public mutating func collapse() {
        isExpanded = false
    }
    
    public mutating func bulkCollapse() {
        isExpanded = false
        // Recursion handled in GraphModel for full graph access
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
public struct GraphState: Codable {  // NEW: Make Codable
    public let nodes: [any NodeProtocol]
    public let edges: [GraphEdge]
    public let hierarchyEdgeColor: CodableColor  // NEW
    public let associationEdgeColor: CodableColor  // NEW
    
    public init(nodes: [any NodeProtocol], edges: [GraphEdge], hierarchyEdgeColor: CodableColor, associationEdgeColor: CodableColor) {
        self.nodes = nodes
        self.edges = edges
        self.hierarchyEdgeColor = hierarchyEdgeColor
        self.associationEdgeColor = associationEdgeColor
    }
    
    // NEW: Codable conformance (leverage existing Codable types)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Nodes: Assume NodeProtocol gets a Codable extension if needed; for now, use NodeWrapper if available
        let wrappedNodes = try container.decode([NodeWrapper].self, forKey: .nodes)
        nodes = wrappedNodes.map { $0.value }
        edges = try container.decode([GraphEdge].self, forKey: .edges)
        hierarchyEdgeColor = try container.decode(CodableColor.self, forKey: .hierarchyEdgeColor)
        associationEdgeColor = try container.decode(CodableColor.self, forKey: .associationEdgeColor)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Nodes: Wrap in NodeWrapper for encoding
        let wrappedNodes = nodes.map { NodeWrapper(wrapping: $0) }  // Wrap NodeProtocol using NodeWrapper.init(wrapping:)
        try container.encode(wrappedNodes, forKey: .nodes)
        try container.encode(edges, forKey: .edges)
        try container.encode(hierarchyEdgeColor, forKey: .hierarchyEdgeColor)
        try container.encode(associationEdgeColor, forKey: .associationEdgeColor)
    }
    
    enum CodingKeys: String, CodingKey {  // NEW
        case nodes, edges, hierarchyEdgeColor, associationEdgeColor
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
    
    // Convenience initializer to wrap any NodeProtocol into a concrete case
    public init(wrapping node: any NodeProtocol) {
        if let anyNode = node as? AnyNode {
            // Handle already-wrapped: Flatten by wrapping the inner unwrapped node
            self.init(wrapping: anyNode.unwrapped)
        } else if let concrete = node as? Node {
            self = .node(concrete)
        } else if let concrete = node as? ToggleNode {
            self = .toggleNode(concrete)
        } else {
            // Fallback: attempt to downcast via Mirror if more types are added in future
            fatalError("Unsupported NodeProtocol concrete type: \(type(of: node))")
        }
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

public enum GraphMode: Codable {  // Codable for saving
    case network  // General graphs, allows cycles/associations
    case tree     // Enforces acyclicity, hierarchy only
}

public protocol HierarchicalNode {
    var children: [UUID] { get set }
    var isExpanded: Bool { get set }
    mutating func collapse()  // Set isExpanded = false
    mutating func bulkCollapse()  // Recursive on children (needs graph access)
}

// Codable wrapper for SwiftUI.Color to avoid extending imported types with protocol conformances
public struct CodableColor: Codable, Equatable {
    public var color: Color

    public init(_ color: Color) {
        self.color = color
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // We store a string description for backward compatibility with previous approach
        let description = try container.decode(String.self)
        self.color = CodableColor.color(fromDescription: description) ?? .black
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(color.description)
    }

    // Helper to parse Color from a description string like
    // "SwiftUI.Color(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0)"
    private static func color(fromDescription description: String) -> Color? {
        let cleaned = description
            .replacingOccurrences(of: "SwiftUI.Color(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let pairs = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var red: Double = 0.0
        var green: Double = 0.0
        var blue: Double = 0.0
        var opacity: Double = 1.0
        for pair in pairs {
            let parts = pair.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                let value = Double(parts[1]) ?? 0.0
                switch parts[0] {
                case "red": red = value
                case "green": green = value
                case "blue": blue = value
                case "opacity": opacity = value
                default: break
                }
            }
        }
        return Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}
