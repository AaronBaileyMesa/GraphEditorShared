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
public struct GraphState: Codable {
    public let nodes: [AnyNode]
    public let edges: [GraphEdge]
    public let hierarchyEdgeColor: CodableColor
    public let associationEdgeColor: CodableColor
    public let uiConfig: [NodeID: [ControlConfig]]
    public let globalUiConfig: [ControlConfig]
    
    public init(
        nodes: [AnyNode],
        edges: [GraphEdge],
        hierarchyEdgeColor: CodableColor,
        associationEdgeColor: CodableColor,
        uiConfig: [NodeID: [ControlConfig]] = [:],
        globalUiConfig: [ControlConfig] = []
    ) {
        self.nodes = nodes
        self.edges = edges
        self.hierarchyEdgeColor = hierarchyEdgeColor
        self.associationEdgeColor = associationEdgeColor
        self.uiConfig = uiConfig
        self.globalUiConfig = globalUiConfig
    }
    
    // MARK: - Codable (Clean, direct, no NodeWrapper needed)
    private enum CodingKeys: String, CodingKey {
        case nodes, edges, hierarchyEdgeColor, associationEdgeColor, uiConfig, globalUiConfig
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nodes = try container.decode([AnyNode].self, forKey: .nodes)           // Direct!
        self.edges = try container.decode([GraphEdge].self, forKey: .edges)
        self.hierarchyEdgeColor = try container.decode(CodableColor.self, forKey: .hierarchyEdgeColor)
        self.associationEdgeColor = try container.decode(CodableColor.self, forKey: .associationEdgeColor)
        self.uiConfig = try container.decode([NodeID: [ControlConfig]].self, forKey: .uiConfig)
        self.globalUiConfig = try container.decode([ControlConfig].self, forKey: .globalUiConfig)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)                                 // Direct!
        try container.encode(edges, forKey: .edges)
        try container.encode(hierarchyEdgeColor, forKey: .hierarchyEdgeColor)
        try container.encode(associationEdgeColor, forKey: .associationEdgeColor)
        try container.encode(uiConfig, forKey: .uiConfig)
        try container.encode(globalUiConfig, forKey: .globalUiConfig)
    }
}

@available(iOS 16.0, *)
@available(watchOS 9.0, *)

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

extension HierarchicalNode {
    public func shouldHideChildren() -> Bool {
        return false  // Regular Node or future types never hide children
    }
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
