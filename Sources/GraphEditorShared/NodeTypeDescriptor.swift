// Sources/GraphEditorShared/NodeTypeDescriptor.swift

import SwiftUI
import Foundation

/// Declarative configuration for a node type's physics, rendering, and behavior.
/// This protocol centralizes all type-specific configuration in one place,
/// eliminating the need for scattered type-checking throughout the codebase.
@available(iOS 16.0, watchOS 9.0, *)
public protocol NodeTypeDescriptor {
    // MARK: - Physics Configuration

    /// Physics mass (default: 1.0)
    var mass: CGFloat { get }

    /// Base radius for physics calculations (default: 20.0)
    var physicsRadius: CGFloat { get }

    /// Physics constraints applied to this node
    var constraints: [NodeConstraint] { get }

    // MARK: - Visual Configuration

    /// Visual rendering strategy
    var renderer: NodeRenderer { get }

    /// Visual size multiplier (default: 1.0)
    var visualMultiplier: CGFloat { get }

    /// Base fill color (can be state-dependent)
    var baseFillColor: Color { get }

    /// Optional icon to display
    var icon: NodeIcon? { get }

    // MARK: - Interaction Configuration

    /// Tap behavior strategy
    var tapBehavior: NodeTapBehavior { get }

    /// Whether node can collapse/expand
    var isCollapsible: Bool { get }

    /// Custom drag behavior (default: standard position update)
    var dragBehavior: NodeDragBehavior? { get }

    // MARK: - Menu Configuration

    /// Menu sections for this node type
    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection]

    // MARK: - Animation Configuration

    /// Animation set for this node type
    var animations: NodeAnimationSet { get }

    /// Haptic feedback patterns
    var haptics: NodeHapticSet { get }
}

// MARK: - Default Implementations

@available(iOS 16.0, watchOS 9.0, *)
public extension NodeTypeDescriptor {
    var mass: CGFloat { 1.0 }
    var physicsRadius: CGFloat { 20.0 }
    var constraints: [NodeConstraint] { [] }
    var visualMultiplier: CGFloat { 1.0 }
    var baseFillColor: Color { .blue }
    var icon: NodeIcon? { nil }
    var tapBehavior: NodeTapBehavior { .toggleExpansion }
    var isCollapsible: Bool { true }
    var dragBehavior: NodeDragBehavior? { nil }
    var animations: NodeAnimationSet { .default }
    var haptics: NodeHapticSet { .default }
}

// MARK: - Supporting Types

/// Icon types for node rendering
@available(iOS 16.0, watchOS 9.0, *)
public enum NodeIcon {
    case systemName(String)
    case custom(String)
    case emoji(String)
}

/// Tap behavior strategies
@available(iOS 16.0, watchOS 9.0, *)
public enum NodeTapBehavior {
    case toggleExpansion
    case select
    case none
    case custom((any NodeProtocol) -> (any NodeProtocol))
}

/// Custom drag behavior for specialized nodes
@available(iOS 16.0, watchOS 9.0, *)
public protocol NodeDragBehavior {
    /// Apply custom drag logic, returning updated position
    func applyDrag(
        to node: any NodeProtocol,
        translation: CGSize,
        context: DragContext
    ) -> CGPoint
}

/// Context provided during drag operations
@available(iOS 16.0, watchOS 9.0, *)
public struct DragContext {
    public let allNodes: [any NodeProtocol]
    public let zoomScale: CGFloat
    public let canvasBounds: CGSize

    public init(allNodes: [any NodeProtocol], zoomScale: CGFloat, canvasBounds: CGSize) {
        self.allNodes = allNodes
        self.zoomScale = zoomScale
        self.canvasBounds = canvasBounds
    }
}

// MARK: - Animation Configuration

/// Animation configuration for a node type
@available(iOS 16.0, watchOS 9.0, *)
public struct NodeAnimationSet {
    public let selection: NodeAnimation?
    public let deselection: NodeAnimation?
    public let stateChange: NodeAnimation?
    public let appear: NodeAnimation?
    public let disappear: NodeAnimation?

    public init(
        selection: NodeAnimation? = nil,
        deselection: NodeAnimation? = nil,
        stateChange: NodeAnimation? = nil,
        appear: NodeAnimation? = nil,
        disappear: NodeAnimation? = nil
    ) {
        self.selection = selection
        self.deselection = deselection
        self.stateChange = stateChange
        self.appear = appear
        self.disappear = disappear
    }

    public static let `default` = NodeAnimationSet(
        selection: .pulse(color: .blue.opacity(0.3), duration: 0.3),
        deselection: .fadeOut(duration: 0.2),
        stateChange: .crossfade(duration: 0.25),
        appear: .scaleIn(duration: 0.3),
        disappear: .scaleOut(duration: 0.2)
    )

    public static let none = NodeAnimationSet()
}

/// Individual animation definition
@available(iOS 16.0, watchOS 9.0, *)
public enum NodeAnimation {
    case pulse(color: Color, duration: TimeInterval)
    case fadeOut(duration: TimeInterval)
    case fadeIn(duration: TimeInterval)
    case scaleIn(duration: TimeInterval)
    case scaleOut(duration: TimeInterval)
    case crossfade(duration: TimeInterval)
    case bounce(amplitude: CGFloat, duration: TimeInterval)
    case rotate(degrees: Double, duration: TimeInterval)
    case shake(intensity: CGFloat, duration: TimeInterval)
}

// MARK: - Haptic Configuration

/// Haptic feedback configuration for a node type
@available(iOS 16.0, watchOS 9.0, *)
public struct NodeHapticSet {
    public let tap: HapticPattern?
    public let longPress: HapticPattern?
    public let drag: HapticPattern?
    public let drop: HapticPattern?
    public let stateChange: HapticPattern?

    public init(
        tap: HapticPattern? = nil,
        longPress: HapticPattern? = nil,
        drag: HapticPattern? = nil,
        drop: HapticPattern? = nil,
        stateChange: HapticPattern? = nil
    ) {
        self.tap = tap
        self.longPress = longPress
        self.drag = drag
        self.drop = drop
        self.stateChange = stateChange
    }

    public static let `default` = NodeHapticSet(
        tap: .click,
        longPress: .click,
        drag: .click,
        drop: .click,
        stateChange: .click
    )

    public static let none = NodeHapticSet()
}

/// Haptic pattern definition
@available(iOS 16.0, watchOS 9.0, *)
public enum HapticPattern {
    case click
    case success
    case failure
    case directionUp
    case directionDown
}
