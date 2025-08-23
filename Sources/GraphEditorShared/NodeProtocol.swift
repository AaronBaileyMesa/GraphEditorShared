// Sources/GraphEditorShared/NodeProtocol.swift

import SwiftUI
import Foundation

private var nodeTextCache: [String: GraphicsContext.ResolvedText] = [:]
private let maxCacheSize = 100  // Arbitrary limit; adjust based on testing
private let nodeCacheQueue = DispatchQueue(label: "nodeTextCache", attributes: .concurrent)
private var insertionOrder: [String] = []  // New: Track order


/// Protocol for graph nodes, enabling polymorphism for types like standard or toggleable nodes.
/// Conformers must provide core properties; defaults are available for common behaviors.
@available(iOS 13.0, *)
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
    
    /// Creates a copy with updated position and velocity.
    func with(position: CGPoint, velocity: CGPoint) -> Self
    
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

/// Extension providing default implementations for non-rendering behaviors.
/// These can be overridden in conformers for custom logic.
@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public extension NodeProtocol {
    /// Default: No change on tap.
    func handlingTap() -> Self { self }
    
    /// Default: Node is always visible.
    var isVisible: Bool { true }
    
    var fillColor: Color { .red }  // Default to red for all nodes
    
    var isExpanded: Bool {
        get { true }  // Default: Always expanded (non-toggle nodes ignore)
        set { }  // No-op setter for non-mutating types
    }
    
    func shouldHideChildren() -> Bool {
        !isExpanded  // Default: Hide if not expanded
    }
}

/// Extension providing default rendering implementations using GraphicsContext.
/// Override for custom node appearances (e.g., different shapes/colors).
@available(iOS 15.0, *)
@available(watchOS 9.0, *)
public extension NodeProtocol {
    func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(Canvas { context, _ in
            self.draw(in: context, at: .zero, zoomScale: zoomScale, isSelected: isSelected)
        })
    }
    
    func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
        let scaledRadius = radius * zoomScale
        let borderWidth: CGFloat = isSelected ? 4 * zoomScale : 0
        let borderRadius = scaledRadius + borderWidth / 2
        
        if borderWidth > 0 {
            let borderPath = Path(ellipseIn: CGRect(x: position.x - borderRadius, y: position.y - borderRadius, width: 2 * borderRadius, height: 2 * borderRadius))
            context.stroke(borderPath, with: .color(.yellow), lineWidth: borderWidth)
        }
        
        let innerPath = Path(ellipseIn: CGRect(x: position.x - scaledRadius, y: position.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius))
        context.fill(innerPath, with: .color(.red))
        
        // Always draw label (removed if isSelected)
        let fontSize = UIFontMetrics.default.scaledValue(for: 12) * zoomScale
        let labelKey = "\(label)-\(fontSize)"
        let resolved: GraphicsContext.ResolvedText = nodeCacheQueue.sync {
            if let cached = nodeTextCache[labelKey] { return cached }
            let text = Text("\(label)").foregroundColor(.white).font(.system(size: fontSize))
            let resolved = context.resolve(text)
            nodeCacheQueue.async(flags: .barrier) {
                nodeTextCache[labelKey] = resolved
                insertionOrder.append(labelKey)  // Add to order
                if nodeTextCache.count > maxCacheSize {
                    let oldestKey = insertionOrder.removeFirst()  // True oldest
                    nodeTextCache.removeValue(forKey: oldestKey)
                }
            }
            return resolved
        }
        let labelPosition = CGPoint(x: position.x, y: position.y - (radius * zoomScale + 10 * zoomScale))
        context.draw(resolved, at: labelPosition, anchor: .center)
    }
}

public struct AnyNode: NodeProtocol, Equatable {
    private var base: any NodeProtocol  // Changed to var for mutability
    
    public var unwrapped: any NodeProtocol { base }  // Public accessor to avoid private exposure
    
    public var id: NodeID { base.id }
    public var label: Int { base.label }
    public var position: CGPoint {
        get { base.position }
        set { base.position = newValue }  // Now mutates var base
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
    
    public init(_ base: any NodeProtocol) {
        self.base = base
    }
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        var newBase = base
        newBase.position = position
        newBase.velocity = velocity
        return AnyNode(newBase)
    }
    
    public func handlingTap() -> Self {
        AnyNode(base.handlingTap())
    }
    
    public func shouldHideChildren() -> Bool {
        base.shouldHideChildren()
    }
    
    // Rendering methods: Forward to base
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        base.renderView(zoomScale: zoomScale, isSelected: isSelected)
    }
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
        base.draw(in: context, at: position, zoomScale: zoomScale, isSelected: isSelected)
    }
    
    // Equatable: Compare via id (adjust if your protocol uses different equality)
    public static func == (lhs: AnyNode, rhs: AnyNode) -> Bool {
        lhs.id == rhs.id
    }
    
    // Codable: Forward to NodeWrapper for polymorphic handling
    public init(from decoder: Decoder) throws {
        let wrapper = try NodeWrapper(from: decoder)
        self.base = wrapper.value
    }
    
    public func encode(to encoder: Encoder) throws {
        // Wrap base in NodeWrapper and encode that
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
