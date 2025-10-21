// Sources/GraphEditorShared/NodeProtocol.swift

import SwiftUI
import Foundation
import os

@available(iOS 15.0, *)
private var nodeTextCache: [String: GraphicsContext.ResolvedText] = [:]
private let maxCacheSize = 100  // Arbitrary limit; adjust based on testing
private let nodeCacheQueue = DispatchQueue(label: "nodeTextCache", attributes: .concurrent)
private var insertionOrder: [String] = []  // New: Track order

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

public enum NodeContent: Codable, Equatable {
    case string(String)
    case date(Date)
    case number(Double)
    
    public var displayText: String {
        switch self {
        case .string(let str): return str.prefix(10) + (str.count > 10 ? "…" : "")
        case .date(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            formatter.timeZone = TimeZone(secondsFromGMT: 0)  // Use UTC for consistency
            formatter.locale = Locale(identifier: "en_US")  // Set locale for consistent output
            return formatter.string(from: date)
        case .number(let num): return String(format: "%.2f", num)
        }
    }
}

extension NodeProtocol {
    public var isVisible: Bool { true }  // Default visible
    
    public var fillColor: Color { .blue }  // Default fill
    
    public var mass: CGFloat { 1.0 }  // Default mass
    
    public func shouldHideChildren() -> Bool { false }  // Default: show children
    
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
        
        // TEMP: Placeholder for contents list drawing (full impl in Step 3)
        if !contents.isEmpty && zoomScale > 0.5 {
            // Add drawing code later
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
