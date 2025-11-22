//
//  ControlNode.swift
//  GraphEditorShared
//
//  Created by handcart on 2025-11-22
//

import SwiftUI

/// Ephemeral on-screen control that behaves exactly like a normal node
/// (physics, rendering, hit-testing) but is never persisted.
public struct ControlNode: NodeProtocol, Codable {
    
    // MARK: Hierarchical state required by NodeProtocol / AnyNode
    public var isExpanded: Bool = false               // never used
    public var children: [NodeID] = []                 // never used
    public var childOrder: [NodeID] = []               // never used
    
    // MARK: Core NodeProtocol properties
    public let id: NodeID = NodeID()
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = Constants.App.nodeModelRadius * 0.75
    public var contents: [NodeContent] = []
    
    // MARK: Control-specific
    public let ownerID: NodeID
    public let kind: ControlKind
    
    // Never displayed as a number
    public var label: Int { kind.rawValue }
    
    public var fillColor: Color {
        switch kind {
        case .addNode:          return .green
        case .addToggleNode:    return .mint
        case .delete:           return .red
        case .toggle:           return .orange
        }
    }
    
    // MARK: Init
    public init(
        position: CGPoint,
        ownerID: NodeID,
        kind: ControlKind
    ) {
        self.position = position
        self.ownerID = ownerID
        self.kind = kind
    }
    
    // MARK: NodeProtocol required methods
    
    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        ControlNode(position: position, ownerID: ownerID, kind: kind)
            .settingVelocity(velocity)
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        var copy = self.with(position: position, velocity: velocity)
        copy.contents = contents
        return copy
    }
    
    public func handlingTap() -> Self {
        self  // actual behaviour is handled in GraphModel
    }
    
    public func shouldHideChildren() -> Bool { false }
    
    @available(iOS 15.0, watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        let iconName: String
        switch kind {
        case .addNode:          iconName = "plus.circle.fill"
        case .addToggleNode:    iconName = "power.circle.fill"
        case .delete:           iconName = "trash.circle.fill"
        case .toggle:           iconName = "chevron.up.chevron.down.circle.fill"
        }
        
        return AnyView(
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: radius * 2 * zoomScale, height: radius * 2 * zoomScale)
                
                Image(systemName: iconName)
                    .font(.system(size: 18 * zoomScale, weight: .medium))
                    .foregroundColor(.white)
            }
            .opacity(isSelected ? 0.9 : 1.0)
        )
    }
    
    // Helper to avoid duplicating all the properties in `with(position:velocity:)`
    private func settingVelocity(_ velocity: CGPoint) -> Self {
        var copy = self
        copy.velocity = velocity
        return copy
    }
}

// MARK: - ControlKind

public enum ControlKind: Int, Codable, CaseIterable {
    case addNode
    case addToggleNode
    case delete
    case toggle
}

// MARK: - Equatable (for AnyNode diffing, even though we filter them out)

extension ControlNode: Equatable {
    public static func == (lhs: ControlNode, rhs: ControlNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.kind == rhs.kind &&
        lhs.ownerID == rhs.ownerID &&
        lhs.position == rhs.position &&
        lhs.velocity == rhs.velocity
    }
}
