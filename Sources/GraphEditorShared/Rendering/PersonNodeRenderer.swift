// Sources/GraphEditorShared/Rendering/PersonNodeRenderer.swift

import SwiftUI
import Foundation

/// Custom renderer for PersonNode with contact thumbnail support
@available(iOS 16.0, watchOS 9.0, *)
public struct PersonNodeRenderer: NodeRenderer {
    public init() {}

    public func renderShape(
        context: inout GraphicsContext,
        node: any NodeProtocol,
        screenPosition: CGPoint,
        zoomScale: CGFloat,
        isSelected: Bool
    ) {
        guard let personNode = node as? PersonNode else {
            // Fallback to circle renderer
            CircleNodeRenderer().renderShape(
                context: &context,
                node: node,
                screenPosition: screenPosition,
                zoomScale: zoomScale,
                isSelected: isSelected
            )
            return
        }

        let radius = node.displayRadius * zoomScale
        let circlePath = Circle()
            .path(in: CGRect(
                x: screenPosition.x - radius,
                y: screenPosition.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

        // Check if we have a contact thumbnail
        if let thumbnailData = personNode.thumbnailImageData,
           let cgImage = createCGImage(from: thumbnailData) {
            // Draw the contact thumbnail
            let imageRect = CGRect(
                x: screenPosition.x - radius,
                y: screenPosition.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            
            // Clip to circle
            context.clip(to: circlePath)
            
            // Draw image
            context.draw(Image(decorative: cgImage, scale: 1.0), in: imageRect)
            
            // Reset clip
            context.clipToLayer { layerContext in
                // Draw border over the image
                let strokeWidth = isSelected ? 3.0 * zoomScale : 2.0 * zoomScale
                layerContext.stroke(
                    circlePath,
                    with: .color(.white.opacity(0.5)),
                    lineWidth: strokeWidth
                )
            }
        } else {
            // Default rendering with blue circle and person icon
            context.fill(circlePath, with: .color(node.fillColor))

            // Draw person icon
            let iconSize = 12.0 * zoomScale
            let iconRect = CGRect(
                x: screenPosition.x - iconSize / 2,
                y: screenPosition.y - iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            
            // Use SF Symbol for person icon
            if let personIcon = context.resolveSymbol(id: "person.fill") {
                context.draw(personIcon, in: iconRect)
            }

            // Stroke
            let strokeWidth = isSelected ? 3.0 * zoomScale : 1.5 * zoomScale
            context.stroke(
                circlePath,
                with: .color(.white.opacity(0.8)),
                lineWidth: strokeWidth
            )
        }
    }

    public func renderView(
        node: any NodeProtocol,
        zoomScale: CGFloat,
        isSelected: Bool
    ) -> AnyView {
        guard let personNode = node as? PersonNode else {
            return CircleNodeRenderer().renderView(
                node: node,
                zoomScale: zoomScale,
                isSelected: isSelected
            )
        }

        if let thumbnailData = personNode.thumbnailImageData,
           let uiImage = UIImage(data: thumbnailData) {
            // Display contact thumbnail
            return AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: node.displayRadius * 2 * zoomScale,
                        height: node.displayRadius * 2 * zoomScale
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                Color.white.opacity(0.5),
                                lineWidth: isSelected ? 3 : 2
                            )
                    )
            )
        } else {
            // Default rendering
            return AnyView(
                ZStack {
                    Circle()
                        .fill(node.fillColor)
                        .frame(
                            width: node.displayRadius * 2 * zoomScale,
                            height: node.displayRadius * 2 * zoomScale
                        )
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: max(8.0, 12.0 * zoomScale), weight: .medium))
                        .foregroundColor(.white)
                }
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.8), lineWidth: isSelected ? 3 : 1.5)
                )
            )
        }
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

    // MARK: - Helper Methods

    private func createCGImage(from data: Data) -> CGImage? {
        #if canImport(UIKit)
        return UIImage(data: data)?.cgImage
        #else
        return nil
        #endif
    }
}
