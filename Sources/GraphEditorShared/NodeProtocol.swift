// Sources/GraphEditorShared/NodeProtocol.swift

import SwiftUI
import Foundation
import os

@available(iOS 15.0, *)
private var nodeTextCache: [String: GraphicsContext.ResolvedText] = [:]
private let maxCacheSize = 100  // Arbitrary limit; adjust based on testing
private let nodeCacheQueue = DispatchQueue(label: "nodeTextCache", attributes: .concurrent)
private var insertionOrder: [String] = []  // New: Track order

// NEW: Define NodeContent enum here (was missing; added with all primitives)
public enum NodeContent: Codable, Equatable {
    case string(String)
    case date(Date)
    case number(Double)
    case boolean(Bool)
    
    public var displayText: String {
        switch self {
        case .string(let value): return value.prefix(10) + (value.count > 10 ? "…" : "")
        case .date(let value):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            formatter.timeZone = TimeZone(secondsFromGMT: 0)  // Force UTC for consistent output
            return formatter.string(from: value)
        case .number(let value): return String(format: "%.2f", value)  // Format to 2 decimal places
        case .boolean(let value): return value ? "True" : "False"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "string":
            let value = try container.decode(String.self, forKey: .value)
            self = .string(value)
        case "date":
            let value = try container.decode(Date.self, forKey: .value)
            self = .date(value)
        case "number":
            let value = try container.decode(Double.self, forKey: .value)
            self = .number(value)
        case "boolean":
            let value = try container.decode(Bool.self, forKey: .value)
            self = .boolean(value)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown NodeContent type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let value):
            try container.encode("string", forKey: .type)
            try container.encode(value, forKey: .value)
        case .date(let value):
            try container.encode("date", forKey: .type)
            try container.encode(value, forKey: .value)
        case .number(let value):
            try container.encode("number", forKey: .type)
            try container.encode(value, forKey: .value)
        case .boolean(let value):
            try container.encode("boolean", forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

/// Protocol for graph nodes, enabling polymorphism for types like standard or toggleable nodes.
/// Conformers must provide core properties; defaults are available for common behaviors.
@available(iOS 16.0, *)
@available(watchOS 9.0, *)
public protocol NodeProtocol: Identifiable, Equatable, Codable where ID == NodeID {
    
    /// Unique identifier for the node.
    var id: NodeID { get }
    
    /// Permanent label for the node (e.g., for display and accessibility).
    var label: Int { get }
    
    /// Current position in the graph canvas.
    var position: CGPoint { get set }
    
    /// Velocity vector for physics simulation.
    var velocity: CGPoint { get set }
    
    /// Radius for rendering and hit detection.
    var radius: CGFloat { get set }
    var displayRadius: CGFloat { get }
    
    /// Expansion state for hierarchical nodes (e.g., true shows children).
    var isExpanded: Bool { get set }
    
    var children: [UUID] { get set }
    mutating func collapse()
    mutating func bulkCollapse()
    
    // Data payload for the node
    // Ordered list of data payloads for the node (replaces single optional content)
    var contents: [NodeContent] { get set }
    
    /// Mass for physics calculations (default: 1.0).
    var mass: CGFloat { get }
    
    /// Creates a copy with updated position and velocity.
    func with(position: CGPoint, velocity: CGPoint) -> Self
    
    /// Creates a copy with updated position, velocity, and optional new contents list.
    func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self
    
    /// Renders the node as a SwiftUI view, customizable by zoom and selection.
    /// - Parameters:
    ///   - zoomScale: Current zoom level of the canvas.
    ///   - isSelected: Whether the node is selected (e.g., for border highlight).
    /// - Returns: A SwiftUI view representing the node.
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView
    
    /// Handles tap gestures, returning a mutated copy (immutable pattern).
    /// - Returns: Updated node after tap (e.g., toggled state).
    func handlingTap() -> Self
    
    /// Indicates if the node is visible in the graph.
    var isVisible: Bool { get }
    
    /// Configurable fill color for the node's roundel.
    var fillColor: Color { get }
    
    /// Determines if child nodes (via outgoing edges) should be hidden.
    /// - Returns: True if children should be hidden (e.g., collapsed toggle).
    func shouldHideChildren() -> Bool
}

extension NodeProtocol {
    public var isVisible: Bool { true }  // Default visible
    
    public var fillColor: Color { .blue }  // Default fill
    
    public var mass: CGFloat { 1.0 }  // Default mass
    
    public func shouldHideChildren() -> Bool {
        if let toggle = self as? ToggleNode {
            return !toggle.isExpanded
        } else {
            return false  // Critical: Non-ToggleNodes (e.g., Node) should NOT hide children
        }
    }
    
    public mutating func collapse() {
        isExpanded = false
    }
    
    public mutating func bulkCollapse() {
        collapse()  // Full recursion handled in GraphModel
    }
    
    public func handlingTap() -> Self { self }  // Default: no-op
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        var newSelf = self
        newSelf.position = position
        newSelf.velocity = velocity
        return newSelf
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        var newSelf = self
        newSelf.position = position
        newSelf.velocity = velocity
        newSelf.contents = contents
        return newSelf
    }
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(Circle().fill(fillColor).frame(width: radius * 2 * zoomScale, height: radius * 2 * zoomScale))
    }

}

@available(iOS 16.0, *)
@available(watchOS 9.0, *)
// MARK: - AnyNode – Type-Erased Wrapper (FINAL VERSION)

public struct AnyNode: NodeProtocol {
    var base: any NodeProtocol
    
    // Hierarchical state we must preserve across type erasure
    public var isExpanded: Bool
    public var children: [UUID]  // Changed to [UUID] to match protocol
    public var childOrder: [UUID]  // Assuming NodeID == UUID; adjust if needed
    
    // MARK: Forwarded NodeProtocol requirements
    public var id: NodeID { base.id }
    public var label: Int { base.label }
    public var position: CGPoint {
        get { base.position }
        set { base.position = newValue }
    }
    public var velocity: CGPoint {
        get { base.velocity }
        set { base.velocity = newValue }
    }
    public var radius: CGFloat {
        get { base.radius }
        set { base.radius = newValue }  // FIXED: Added missing setter to conform to protocol
    }
    public var contents: [NodeContent] {
        get { base.contents }
        set { base.contents = newValue }
    }
    public var fillColor: Color { base.fillColor }
    public var unwrapped: any NodeProtocol { base }

    public init(_ base: any NodeProtocol) {
        self.base = base
        
        if let toggle = base as? ToggleNode {
            self.isExpanded = toggle.isExpanded
            self.children = toggle.children
            self.childOrder = toggle.childOrder
        } else if let hierarchical = base as? any HierarchicalNode {
            self.isExpanded = hierarchical.isExpanded
            self.children = hierarchical.children
            self.childOrder = []
        } else {
            self.isExpanded = true
            self.children = []
            self.childOrder = []
        }
    }
    
    // MARK: Required NodeProtocol methods (fixed & clean)
    
    public func with(position: CGPoint, velocity: CGPoint) -> AnyNode {
        AnyNode(base.with(position: position, velocity: velocity))
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> AnyNode {
        AnyNode(base.with(position: position, velocity: velocity, contents: contents))
    }
    
    public func handlingTap() -> AnyNode {
        AnyNode(base.handlingTap()) // ← now preserves isExpanded perfectly
    }
    
    public func shouldHideChildren() -> Bool {
        base.shouldHideChildren()
    }
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        base.renderView(zoomScale: zoomScale, isSelected: isSelected)
    }
    
    // MARK: Codable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "node":
            let node = try container.decode(Node.self, forKey: .data)
            self.init(node)
        case "toggleNode":
            let toggleNode = try container.decode(ToggleNode.self, forKey: .data)
            self.init(toggleNode)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                debugDescription: "Unknown node type: \(type)")
        }
        
        // Always reset velocity on load (physics state is transient)
        self.velocity = .zero
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if let node = base as? Node {
            try container.encode("node", forKey: .type)
            try container.encode(node, forKey: .data)
        } else if let toggleNode = base as? ToggleNode {
            try container.encode("toggleNode", forKey: .type)
            try container.encode(toggleNode, forKey: .data)
        } else {
            throw EncodingError.invalidValue(base, .init(codingPath: [], debugDescription: "Unknown node type"))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    // MARK: Equatable
    public static func == (lhs: AnyNode, rhs: AnyNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.position == rhs.position &&
        lhs.velocity == rhs.velocity &&
        lhs.isExpanded == rhs.isExpanded &&
        lhs.contents == rhs.contents &&
        lhs.children == rhs.children &&
        lhs.childOrder == rhs.childOrder
    }
}

extension NodeProtocol {
    public var displayRadius: CGFloat { radius } 
}

extension NodeProtocol {
    public func fullyUnwrapped() -> any NodeProtocol {
        // Default: For concrete types (e.g., ControlNode, ToggleNode), return self (no unwrapping needed)
        if let anyNode = self as? AnyNode {
            return anyNode.base.fullyUnwrapped()  // Recurse for wrapped
        }
        return self
    }
}
