import SwiftUI
import Foundation

public typealias NodeID = UUID

@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public struct Node: NodeProtocol, Equatable {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = 10.0
    public var isExpanded: Bool = true  // Add: Satisfy protocol (always true for basic Node)
    public var content: NodeContent? = nil
    public var fillColor: Color { .red }  // Explicit red for basic nodes

    // Update init to include radius
    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero, radius: CGFloat = 10.0, content: NodeContent? = nil) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.content = content
    }
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {  // Preserve content
        Node(id: id, label: label, position: position, velocity: velocity, radius: radius, content: content)
         }
    
    // Update CodingKeys and decoder/encoder for radius
    enum CodingKeys: String, CodingKey {
        case id, label, radius, content  // Add radius
        case positionX, positionY
        case velocityX, velocityY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? 10.0  // Decode or default
        self.content = try container.decodeIfPresent(NodeContent.self, forKey: .content) ?? nil  // Decode content
        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        self.position = CGPoint(x: posX, y: posY)
        let velX = try container.decode(CGFloat.self, forKey: .velocityX)
        let velY = try container.decode(CGFloat.self, forKey: .velocityY)
        self.velocity = CGPoint(x: velX, y: velY)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(radius, forKey: .radius)  // Encode radius
        try container.encodeIfPresent(content, forKey: .content)  // Encode content
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
    }
    
        public static func == (lhs: Node, rhs: Node) -> Bool {
            lhs.id == rhs.id &&
            lhs.label == rhs.label &&
            lhs.position == rhs.position &&
            lhs.velocity == rhs.velocity &&
            lhs.radius == rhs.radius &&
            lhs.content == rhs.content
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
    public let to: NodeID
    public let type: EdgeType  // New: Required type
    
    enum CodingKeys: String, CodingKey {
        case id, from, to, type  // Added type
    }
    
    public init(id: NodeID = NodeID(), from: NodeID, to: NodeID, type: EdgeType = .association) {  // Default to .association
        self.id = id
        self.from = from
        self.to = to
        self.type = type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        from = try container.decode(NodeID.self, forKey: .from)
        to = try container.decode(NodeID.self, forKey: .to)
        type = try container.decode(EdgeType.self, forKey: .type)  // Decode type
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(type, forKey: .type)  // Encode type
    }
}

// Snapshot of the graph state for undo/redo.
@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public struct GraphState {
    public let nodes: [any NodeProtocol]
    public let edges: [GraphEdge]
    
    public init(nodes: [any NodeProtocol], edges: [GraphEdge]) {
        self.nodes = nodes
        self.edges = edges
    }
}

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
