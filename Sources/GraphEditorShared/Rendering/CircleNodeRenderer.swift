// Sources/GraphEditorShared/Rendering/CircleNodeRenderer.swift

import SwiftUI
import Foundation

/// Default circular node renderer
@available(iOS 16.0, watchOS 9.0, *)
public struct CircleNodeRenderer: NodeRenderer {
    public init() {}

    public func renderShape(
        context: inout GraphicsContext,
        node: any NodeProtocol,
        screenPosition: CGPoint,
        zoomScale: CGFloat,
        isSelected: Bool
    ) {
        let radius = node.displayRadius * zoomScale
        let circlePath = Circle()
            .path(in: CGRect(
                x: screenPosition.x - radius,
                y: screenPosition.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

        // Fill
        context.fill(circlePath, with: .color(node.fillColor))

        // Stroke
        let strokeWidth = isSelected ? 3.0 * zoomScale : 1.5 * zoomScale
        context.stroke(
            circlePath,
            with: .color(.white.opacity(0.8)),
            lineWidth: strokeWidth
        )
    }

    public func renderView(
        node: any NodeProtocol,
        zoomScale: CGFloat,
        isSelected: Bool
    ) -> AnyView {
        AnyView(
            Circle()
                .fill(node.fillColor)
                .frame(
                    width: node.displayRadius * 2 * zoomScale,
                    height: node.displayRadius * 2 * zoomScale
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.8), lineWidth: isSelected ? 3 : 1.5)
                )
        )
    }

    public func visualBounds(
        for node: any NodeProtocol,
        at screenPosition: CGPoint,
        zoomScale: CGFloat
    ) -> CGRect {
        let radius = node.displayRadius * zoomScale
        return CGRect(
            x: screenPosition.x - radius,
            y: screenPosition.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }
}
