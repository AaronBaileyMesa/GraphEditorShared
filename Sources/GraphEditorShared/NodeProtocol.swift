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
    
    /// Draws the node in a GraphicsContext for efficient Canvas rendering.
    /// - Parameters:
    ///   - context: The GraphicsContext to draw into.
    ///   - position: Center position for drawing.
    ///   - zoomScale: Current zoom level.
    ///   - isSelected: Whether to draw selection highlights.
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool)
}

extension NodeProtocol {
    public var isVisible: Bool { true }  // Default visible
    
    public var fillColor: Color { .blue }  // Default fill
    
    public var mass: CGFloat { 1.0 }  // Default mass
    
    public func shouldHideChildren() -> Bool { false }  // Default: show children
    
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
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
        let scaledRadius = radius * zoomScale
        let path = CGPath(ellipseIn: CGRect(x: position.x - scaledRadius, y: position.y - scaledRadius, width: scaledRadius * 2, height: scaledRadius * 2), transform: nil)
        context.fill(Path(path), with: .color(fillColor))
        context.stroke(Path(path), with: .color(isSelected ? Color.green : Color.white), lineWidth: 2 * zoomScale)
        
        let textKey = "\(label)_\(zoomScale)"
        var labelResolved: GraphicsContext.ResolvedText?
        nodeCacheQueue.sync {
            if let cached = nodeTextCache[textKey] {
                labelResolved = cached
            } else {
                let text = Text("\(label)").font(.system(size: 12 * zoomScale)).foregroundColor(.white)
                let resolved = context.resolve(text)
                nodeTextCache[textKey] = resolved
                insertionOrder.append(textKey)
                if nodeTextCache.count > maxCacheSize {
                    let oldestKey = insertionOrder.removeFirst()
                    nodeTextCache.removeValue(forKey: oldestKey)
                }
                labelResolved = resolved
            }
        }
        context.draw(labelResolved!, at: position, anchor: .center)
        
        // NEW: Draw contents list vertically below node
        if !contents.isEmpty && zoomScale > 0.5 {  // Only if zoomed
            var yOffset = scaledRadius + 5 * zoomScale  // Start below node
            let contentFontSize = max(6.0, 8.0 * zoomScale)
            let maxItems = 3  // Limit for watchOS
            for content in contents.prefix(maxItems) {
                let contentText = Text(content.displayText).font(.system(size: contentFontSize)).foregroundColor(.gray)
                let resolved = context.resolve(contentText)
                let contentPosition = CGPoint(x: position.x, y: position.y + yOffset)
                context.draw(resolved, at: contentPosition, anchor: .center)
                yOffset += 10 * zoomScale  // Line spacing
            }
            if contents.count > maxItems {
                let moreText = Text("+\(contents.count - maxItems) more").font(.system(size: contentFontSize * 0.75)).foregroundColor(.gray)
                let resolved = context.resolve(moreText)
                context.draw(resolved, at: CGPoint(x: position.x, y: position.y + yOffset), anchor: .center)
            }
        }
    }
}

@available(iOS 16.0, *)
@available(watchOS 9.0, *)
public struct AnyNode: NodeProtocol {
    // NEW: Add the static logger here (moved from protocol)
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "nodeprotocol")
    
    private var base: any NodeProtocol  // var for mutability
    
    public var contents: [NodeContent] {
        get { base.contents }
        set { base.contents = newValue }
    }
    
    public var unwrapped: any NodeProtocol { base }
    
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
        set { base.radius = newValue }
    }
    public var isExpanded: Bool {
        get { base.isExpanded }
        set { base.isExpanded = newValue }
    }
    
    public var children: [UUID] {
        get { base.children }
        set { base.children = newValue }
    }

    public mutating func collapse() {
        base.collapse()
    }

    public mutating func bulkCollapse() {
        base.bulkCollapse()
    }
    
    public var isVisible: Bool { base.isVisible }
    public var fillColor: Color { base.fillColor }
    public var mass: CGFloat { base.mass }
    
    public init(_ base: any NodeProtocol) {
        self.base = base
    }
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        var newBase = base
        newBase.position = position
        newBase.velocity = velocity
        return AnyNode(newBase)
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        var newBase = base
        newBase.position = position
        newBase.velocity = velocity
        newBase.contents = contents
        return AnyNode(newBase)
    }
    
    public func handlingTap() -> Self {
        AnyNode(base.handlingTap())
    }
    
    public func shouldHideChildren() -> Bool {
        base.shouldHideChildren()
    }
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        base.renderView(zoomScale: zoomScale, isSelected: isSelected)
    }
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
#if DEBUG
        Self.logger.debug("Drawing node \(label) at (\(position.x), \(position.y)), isSelected: \(isSelected), zoom: \(zoomScale)")
#endif
        base.draw(in: context, at: position, zoomScale: zoomScale, isSelected: isSelected)
    }
    
    public static func == (lhs: AnyNode, rhs: AnyNode) -> Bool {
        lhs.id == rhs.id && lhs.position == rhs.position && lhs.velocity == rhs.velocity &&
        lhs.isExpanded == rhs.isExpanded && lhs.contents == rhs.contents  // Updated for array
    }
    
    public init(from decoder: Decoder) throws {
        let wrapper = try NodeWrapper(from: decoder)
        self.base = wrapper.value
    }
    
    public func encode(to encoder: Encoder) throws {
        let wrapper: NodeWrapper
        if let node = base as? Node {
            wrapper = .node(node)
        } else if let toggleNode = base as? ToggleNode {
            wrapper = .toggleNode(toggleNode)
        } else {
            throw EncodingError.invalidValue(base, EncodingError.Context(codingPath: [], debugDescription: "Unsupported node type"))
        }
        try wrapper.encode(to: encoder)
    }
}
