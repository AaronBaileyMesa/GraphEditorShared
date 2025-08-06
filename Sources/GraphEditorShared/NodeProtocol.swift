// Sources/GraphEditorShared/NodeProtocol.swift

import SwiftUI
import Foundation

@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public protocol NodeProtocol: Identifiable, Equatable, Codable where ID == NodeID {
    var id: NodeID { get }
    var label: Int { get }
    var position: CGPoint { get set }
    var velocity: CGPoint { get set }
    var radius: CGFloat { get set }
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView
    
    func handlingTap() -> Self
    
    var isVisible: Bool { get }
    
    func shouldHideChildren() -> Bool
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool)
}

// Keep your existing extensions (iOS 15.0 for draw/renderView defaults, iOS 13.0 for others if separated)
@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public extension NodeProtocol {
    func handlingTap() -> Self { self }
    var isVisible: Bool { true }
    func shouldHideChildren() -> Bool { false }
}

@available(iOS 15.0, *)
@available(watchOS 9.0, *)
public extension NodeProtocol {
    func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
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

    func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(Canvas { context, _ in
            self.draw(in: context, at: .zero, zoomScale: zoomScale, isSelected: isSelected)  // Draws centered at zero for standalone use
        })
    }
}
