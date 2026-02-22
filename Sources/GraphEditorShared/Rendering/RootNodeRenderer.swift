// Sources/GraphEditorShared/Rendering/RootNodeRenderer.swift

import SwiftUI
import Foundation

/// Custom renderer for RootNode with + symbol and pulse animation
@available(iOS 16.0, watchOS 9.0, *)
public struct RootNodeRenderer: NodeRenderer {
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

        // Fill with light gray
        context.fill(circlePath, with: .color(Color.gray.opacity(0.8)))

        // Draw + symbol in center
        let plusSize: CGFloat = radius * 0.6
        let plusThickness: CGFloat = max(2.0, radius * 0.12)
        
        // Vertical bar of +
        let verticalBar = Path { path in
            path.addRect(CGRect(
                x: screenPosition.x - plusThickness / 2,
                y: screenPosition.y - plusSize / 2,
                width: plusThickness,
                height: plusSize
            ))
        }
        
        // Horizontal bar of +
        let horizontalBar = Path { path in
            path.addRect(CGRect(
                x: screenPosition.x - plusSize / 2,
                y: screenPosition.y - plusThickness / 2,
                width: plusSize,
                height: plusThickness
            ))
        }
        
        // Draw + symbol with accent color
        context.fill(verticalBar, with: .color(Color(red: 0.6, green: 0.25, blue: 0.25)))
        context.fill(horizontalBar, with: .color(Color(red: 0.6, green: 0.25, blue: 0.25)))

        // Stroke with darker gray
        let strokeWidth = isSelected ? 3.0 * zoomScale : 2.0 * zoomScale
        context.stroke(
            circlePath,
            with: .color(Color.gray.opacity(0.6)),
            lineWidth: strokeWidth
        )
    }

    public func renderView(
        node: any NodeProtocol,
        zoomScale: CGFloat,
        isSelected: Bool
    ) -> AnyView {
        // Check if graph is empty (only root node exists) for pulse animation
        let shouldPulse = false  // TODO: Wire up to graph state
        
        return AnyView(
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(
                        width: node.displayRadius * 2 * zoomScale,
                        height: node.displayRadius * 2 * zoomScale
                    )
                
                // + symbol
                PlusSymbol()
                    .fill(Color(red: 0.6, green: 0.25, blue: 0.25))
                    .frame(
                        width: node.displayRadius * 1.2 * zoomScale,
                        height: node.displayRadius * 1.2 * zoomScale
                    )
            }
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.6), lineWidth: isSelected ? 3 : 2)
            )
            .scaleEffect(shouldPulse ? 1.0 : 1.0)  // TODO: Add pulse animation
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

/// Custom shape for + symbol
@available(iOS 16.0, watchOS 9.0, *)
private struct PlusSymbol: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let thickness = rect.width * 0.15
        let length = rect.width * 0.6
        
        // Vertical bar
        path.addRect(CGRect(
            x: rect.midX - thickness / 2,
            y: rect.midY - length / 2,
            width: thickness,
            height: length
        ))
        
        // Horizontal bar
        path.addRect(CGRect(
            x: rect.midX - length / 2,
            y: rect.midY - thickness / 2,
            width: length,
            height: thickness
        ))
        
        return path
    }
}
