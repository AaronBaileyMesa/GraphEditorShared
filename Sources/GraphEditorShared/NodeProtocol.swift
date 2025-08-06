//
//  NodeProtocol.swift
//  GraphEditorShared
//
//  Created by handcart on 8/5/25.
//


import SwiftUI
import Foundation

public protocol NodeProtocol: Identifiable, Equatable, Codable where ID == NodeID {
    var id: NodeID { get }
    var label: Int { get }  // Non-mutating for now; mutations handled via model updates
    var position: CGPoint { get set }
    var velocity: CGPoint { get set }
    var radius: CGFloat { get set }
    
    // Hook for custom rendering (returns a View; passed context like zoomScale and selection state)
    func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView
    
    // Hook for handling interactions (e.g., tap); returns a mutated version of self
    func handlingTap() -> Self
    
    // Hook for visibility (determines if this node should be rendered)
    var isVisible: Bool { get }
    
    // Hook for child-hiding logic (true if descendants via outgoing edges should be hidden)
    func shouldHideChildren() -> Bool
    
    func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool)
}

extension NodeProtocol {
    // Default draw implementation (mirrors renderView logic)
    public func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
        let scaledRadius = radius * zoomScale
        let borderWidth: CGFloat = isSelected ? 4 * zoomScale : 0
        let borderRadius = scaledRadius + borderWidth / 2

        // Draw filled circle
        context.fill(Path(ellipseIn: CGRect(x: position.x - scaledRadius, y: position.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius)), with: .color(.red))  // Default color

        // Draw border if selected
        if isSelected {
            context.stroke(Path(ellipseIn: CGRect(x: position.x - borderRadius, y: position.y - borderRadius, width: 2 * borderRadius, height: 2 * borderRadius)), with: .color(.white), lineWidth: borderWidth)
        }

        // Draw label (with resolve for GraphicsContext compatibility)
        let fontSize = UIFontMetrics.default.scaledValue(for: 12) * zoomScale
        let text = Text("\(label)").foregroundColor(.white).font(.system(size: fontSize))
        let resolved = context.resolve(text)
        context.draw(resolved, at: position, anchor: .center)
    }

    // Optional: Keep renderView as a wrapper if needed elsewhere
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(Canvas { context, _ in
            self.draw(in: context, at: .zero, zoomScale: zoomScale, isSelected: isSelected)  // Draws centered at zero for standalone use
        })
    }
    
    public func handlingTap() -> Self {
        return self  // Default: No change
    }
    
    public var isVisible: Bool {
        true
    }
    
    public func shouldHideChildren() -> Bool {
        false
    }
}
