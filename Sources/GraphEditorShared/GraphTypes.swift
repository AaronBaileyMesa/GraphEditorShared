//
//  GraphTypes.swift
//  GraphEditorShared
//
//  Created by handcart on 2025-09-19 13:45:29

import SwiftUI
import Foundation

public typealias NodeID = UUID

extension NodeID: @retroactive Identifiable {
    public var id: Self { self }
}

@available(iOS 16.0, *)
@available(watchOS 9.0, *)
public struct Node: NodeProtocol, Codable {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = Constants.App.nodeModelRadius
    public var children: [UUID] = []
    public var childOrder: [UUID] = []  // Explicit order for children layout
    public var isExpanded: Bool = true
    public var isCollapsible: Bool = false  // NEW: Controls expand/collapse behavior
    public var contents: [NodeContent] = []
    
    // All nodes use consistent blue color
    public var fillColor: Color {
        .blue
    }

    // Init with all params
    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero, radius: CGFloat = Constants.App.nodeModelRadius, isExpanded: Bool = true, isCollapsible: Bool = false, contents: [NodeContent] = [], children: [UUID] = [], childOrder: [UUID]? = nil) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = isExpanded
        self.isCollapsible = isCollapsible
        self.contents = contents
        self.children = children
        // Validate childOrder to be a permutation of children
        let validatedOrder = (childOrder ?? children).filter { children.contains($0) }
        self.childOrder = validatedOrder.isEmpty ? children : validatedOrder
    }
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        Node(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, isCollapsible: isCollapsible, contents: contents, children: children, childOrder: childOrder)
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        Node(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, isCollapsible: isCollapsible, contents: contents, children: children, childOrder: childOrder)
    }
    
    public func with(children: [NodeID]) -> Self {
        Node(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, isCollapsible: isCollapsible, contents: contents, children: children, childOrder: childOrder)
    }
    
    public func with(childOrder: [NodeID]) -> Self {
        Node(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, isCollapsible: isCollapsible, contents: contents, children: children, childOrder: childOrder)
    }
    
    public func with(isExpanded: Bool) -> Self {
        Node(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, isCollapsible: isCollapsible, contents: contents, children: children, childOrder: childOrder)
    }
    
    public func shouldHideChildren() -> Bool {
        isCollapsible && !isExpanded
    }
    
    public func handlingTap() -> Self {
        guard isCollapsible else { return self }
        var updated = self
        updated.isExpanded.toggle()
        updated.velocity = .zero
        return updated
    }
    
    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius, isExpanded, isCollapsible, contents, children, childOrder
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? Constants.App.nodeModelRadius
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        isCollapsible = try container.decodeIfPresent(Bool.self, forKey: .isCollapsible) ?? false
        contents = try container.decodeIfPresent([NodeContent].self, forKey: .contents) ?? []
        children = try container.decodeIfPresent([NodeID].self, forKey: .children) ?? []
        childOrder = try container.decodeIfPresent([NodeID].self, forKey: .childOrder) ?? []
        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)
        self.velocity = .zero  // Always reset velocity on load (physics state is transient)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(radius, forKey: .radius)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(contents, forKey: .contents)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)
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
    case spring

    // NEW: Home economics edge types
    case ownership      // User → Account (who owns which account)
    case allocation     // Budget → Category (budget applies to category)
    case payment        // Transaction → Account (paid from account)
    case attribution    // User → Transaction (who made the transaction)

    // NEW: Meal planning edge types
    case requires       // Meal → Recipe (meal requires this recipe)
    case contains       // Recipe → Ingredient (recipe contains ingredient)
    case purchases      // ShoppingItem → Ingredient (shopping item provides ingredient)
    case assigned       // User → Task (user assigned to task)
    case participates   // User → Meal (user participated in meal work)
    case precedes       // Task → Task (temporal ordering)
    case costs          // ShoppingItem → Transaction (shopping creates expense)
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
    enum CodingKeys: CodingKey {
        case nodes, edges, hierarchyEdgeColor, associationEdgeColor, uiConfig, globalUiConfig, isSimulating, nextNodeLabel, layoutMode
    }

    public let nodes: [AnyNode]
    public let edges: [GraphEdge]
    public let hierarchyEdgeColor: CodableColor
    public let associationEdgeColor: CodableColor
    public let uiConfig: [NodeID: [ControlConfig]]
    public let globalUiConfig: [ControlConfig]
    public let isSimulating: Bool
    public let nextNodeLabel: Int
    public let layoutMode: LayoutMode

    public init(nodes: [AnyNode] = [], edges: [GraphEdge] = [], hierarchyEdgeColor: CodableColor = CodableColor(.blue), associationEdgeColor: CodableColor = CodableColor(.white), uiConfig: [NodeID: [ControlConfig]] = [:], globalUiConfig: [ControlConfig] = [], isSimulating: Bool = false, nextNodeLabel: Int = 1, layoutMode: LayoutMode = .network) {
        self.nodes = nodes
        self.edges = edges
        self.hierarchyEdgeColor = hierarchyEdgeColor
        self.associationEdgeColor = associationEdgeColor
        self.uiConfig = uiConfig
        self.globalUiConfig = globalUiConfig
        self.isSimulating = isSimulating
        self.nextNodeLabel = nextNodeLabel
        self.layoutMode = layoutMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decode([AnyNode].self, forKey: .nodes)
        edges = try container.decode([GraphEdge].self, forKey: .edges)
        hierarchyEdgeColor = try container.decode(CodableColor.self, forKey: .hierarchyEdgeColor)
        associationEdgeColor = try container.decode(CodableColor.self, forKey: .associationEdgeColor)
        uiConfig = try container.decode([NodeID: [ControlConfig]].self, forKey: .uiConfig)
        globalUiConfig = try container.decode([ControlConfig].self, forKey: .globalUiConfig)
        isSimulating = try container.decodeIfPresent(Bool.self, forKey: .isSimulating) ?? false
        nextNodeLabel = try container.decodeIfPresent(Int.self, forKey: .nextNodeLabel) ?? 1
        layoutMode = try container.decodeIfPresent(LayoutMode.self, forKey: .layoutMode) ?? .network
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(edges, forKey: .edges)
        try container.encode(hierarchyEdgeColor, forKey: .hierarchyEdgeColor)
        try container.encode(associationEdgeColor, forKey: .associationEdgeColor)
        try container.encode(uiConfig, forKey: .uiConfig)
        try container.encode(globalUiConfig, forKey: .globalUiConfig)
        try container.encode(isSimulating, forKey: .isSimulating)
        try container.encode(nextNodeLabel, forKey: .nextNodeLabel)
        try container.encode(layoutMode, forKey: .layoutMode)
    }
}

@available(iOS 16.0, *)
@available(watchOS 9.0, *)

public enum GraphMode: Codable {  // Codable for saving
    case network  // General graphs, allows cycles/associations
    case tree     // Enforces acyclicity, hierarchy only
}

@available(iOS 16.0, *)
@available(watchOS 9.0, *)

public enum LayoutMode: Codable {  // Controls physics layout strategy
    case network     // Centered, symmetric forces - good for general graphs
    case hierarchy   // Top-left anchored, asymmetric forces - good for trees
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
