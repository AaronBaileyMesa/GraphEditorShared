import SwiftUI
import Foundation

public typealias NodeID = UUID

// Replace the entire Node struct in GraphTypes.swift with this corrected version
@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public struct Node: NodeProtocol, Equatable {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = 10.0
    public var isExpanded: Bool = true  // Satisfy protocol (always true for basic Node)
    public var content: NodeContent? = nil
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
    
    public func with(position: CGPoint, velocity: CGPoint, content: NodeContent?) -> Self {
        Node(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, content: content ?? self.content)
    }
    
    public func handlingTap() -> Self { self }  // No-op for basic Node
    
    public func shouldHideChildren() -> Bool { false }  // Basic nodes don't hide children
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(Circle().fill(.red).frame(width: radius * 2 * zoomScale, height: radius * 2 * zoomScale))  // Simple default
    }
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
        let scaledRadius = radius * zoomScale
        let borderWidth: CGFloat = isSelected ? max(3.0, 4 * zoomScale) : 0
        let borderRadius = scaledRadius + borderWidth / 2

        // Draw border if selected
        if borderWidth > 0 {
            let borderPath = Path(ellipseIn: CGRect(x: position.x - borderRadius, y: position.y - borderRadius, width: 2 * borderRadius, height: 2 * borderRadius))
            context.stroke(borderPath, with: .color(.yellow), lineWidth: borderWidth)
        }

        // Draw node circle
        let innerPath = Path(ellipseIn: CGRect(x: position.x - scaledRadius, y: position.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius))
        context.fill(innerPath, with: .color(fillColor))

        // Draw label above node
        let labelFontSize = max(8.0, 12.0 * zoomScale)
        let labelResolved = context.resolve(Text("\(label)").foregroundColor(.white).font(.system(size: labelFontSize)))
        let labelPosition = CGPoint(x: position.x, y: position.y - (scaledRadius + 10 * zoomScale))
        context.draw(labelResolved, at: labelPosition, anchor: .center)

        // Draw content below node if present and zoomed in
        if let content = content, zoomScale > 0.5 {
            let contentFontSize = max(6.0, 8.0 * zoomScale)
            let contentResolved = context.resolve(Text(content.displayText).foregroundColor(.gray).font(.system(size: contentFontSize)))
            let contentPosition = CGPoint(x: position.x, y: position.y + (scaledRadius + 10 * zoomScale))
            context.draw(contentResolved, at: contentPosition, anchor: .center)
        }
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, label, radius, isExpanded, content
        case positionX, positionY
        case velocityX, velocityY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? 10.0
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        content = try container.decodeIfPresent(NodeContent.self, forKey: .content)
        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)
        let velX = try container.decode(CGFloat.self, forKey: .velocityX)
        let velY = try container.decode(CGFloat.self, forKey: .velocityY)
        velocity = CGPoint(x: velX, y: velY)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(radius, forKey: .radius)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encodeIfPresent(content, forKey: .content)
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
        lhs.isExpanded == rhs.isExpanded &&
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
    public let target: NodeID
    public let type: EdgeType  // Required type
    
    enum CodingKeys: String, CodingKey {
        case id, from, to, type
    }
    
    public init(id: NodeID = NodeID(), from: NodeID, to: NodeID, type: EdgeType = .association) {
        self.id = id
        self.from = from
        self.target = to
        self.type = type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        from = try container.decode(NodeID.self, forKey: .from)
        target = try container.decode(NodeID.self, forKey: .to)
        type = try container.decode(EdgeType.self, forKey: .type)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(from, forKey: .from)
        try container.encode(target, forKey: .to)
        try container.encode(type, forKey: .type)
    }
    
    public static func == (lhs: GraphEdge, rhs: GraphEdge) -> Bool {
        lhs.id == rhs.id && lhs.from == rhs.from && lhs.target == rhs.target && lhs.type == rhs.type
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

@available(iOS 13.0, *)
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
