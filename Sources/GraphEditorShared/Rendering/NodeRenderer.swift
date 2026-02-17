// Sources/GraphEditorShared/Rendering/NodeRenderer.swift

import SwiftUI
import Foundation

/// Strategy for rendering a node's visual representation
@available(iOS 16.0, watchOS 9.0, *)
public protocol NodeRenderer {
    /// Render node shape in GraphicsContext (for canvas)
    func renderShape(
        context: inout GraphicsContext,
        node: any NodeProtocol,
        screenPosition: CGPoint,
        zoomScale: CGFloat,
        isSelected: Bool
    )

    /// Render node in SwiftUI (for overlays/previews)
    func renderView(
        node: any NodeProtocol,
        zoomScale: CGFloat,
        isSelected: Bool
    ) -> AnyView

    /// Visual bounds for hit testing
    func visualBounds(
        for node: any NodeProtocol,
        at screenPosition: CGPoint,
        zoomScale: CGFloat
    ) -> CGRect
}
