// Sources/GraphEditorShared/Rendering/RectangleNodeRenderer.swift

import SwiftUI
import Foundation

/// Rectangle node renderer with configurable corner radius and aspect ratio
@available(iOS 16.0, watchOS 9.0, *)
public struct RectangleNodeRenderer: NodeRenderer {
    public let cornerRadius: CGFloat
    public let aspectRatio: CGFloat  // width/height

    public init(cornerRadius: CGFloat = 8, aspectRatio: CGFloat = 1.0) {
        self.cornerRadius = cornerRadius
        self.aspectRatio = aspectRatio
    }

    public func renderShape(
        context: inout GraphicsContext,
        node: any NodeProtocol,
        screenPosition: CGPoint,
        zoomScale: CGFloat,
        isSelected: Bool
    ) {
        let baseSize = node.displayRadius * 2 * zoomScale
        let width: CGFloat
        let height: CGFloat

        if aspectRatio > 1.0 {
            // Wider than tall
            width = baseSize
            height = baseSize / aspectRatio
        } else {
            // Taller than wide
            width = baseSize * aspectRatio
            height = baseSize
        }

        let rectPath = RoundedRectangle(cornerRadius: cornerRadius * zoomScale)
            .path(in: CGRect(
                x: screenPosition.x - width / 2,
                y: screenPosition.y - height / 2,
                width: width,
                height: height
            ))

        context.fill(rectPath, with: .color(node.fillColor))

        let strokeWidth = isSelected ? 3.0 * zoomScale : 1.5 * zoomScale
        context.stroke(
            rectPath,
            with: .color(.white.opacity(0.8)),
            lineWidth: strokeWidth
        )
    }

    public func renderView(
        node: any NodeProtocol,
        zoomScale: CGFloat,
        isSelected: Bool
    ) -> AnyView {
        let baseSize = node.displayRadius * 2 * zoomScale
        let width = aspectRatio > 1.0 ? baseSize : baseSize * aspectRatio
        let height = aspectRatio > 1.0 ? baseSize / aspectRatio : baseSize

        return AnyView(
            RoundedRectangle(cornerRadius: cornerRadius * zoomScale)
                .fill(node.fillColor)
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius * zoomScale)
                        .stroke(.white.opacity(0.8), lineWidth: isSelected ? 3 : 1.5)
                )
        )
    }

    public func visualBounds(
        for node: any NodeProtocol,
        at screenPosition: CGPoint,
        zoomScale: CGFloat
    ) -> CGRect {
        let baseSize = node.displayRadius * 2 * zoomScale
        let width = aspectRatio > 1.0 ? baseSize : baseSize * aspectRatio
        let height = aspectRatio > 1.0 ? baseSize / aspectRatio : baseSize

        return CGRect(
            x: screenPosition.x - width / 2,
            y: screenPosition.y - height / 2,
            width: width,
            height: height
        )
    }
}
