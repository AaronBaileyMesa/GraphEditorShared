// PeopleListNodeRenderer.swift
// GraphEditorShared
//
// Custom renderer for PeopleListNode that shows person count and icon

import SwiftUI
import Foundation

/// Renderer for PeopleListNode showing count badge and people icon
@available(iOS 16.0, watchOS 9.0, *)
public struct PeopleListNodeRenderer: NodeRenderer {
    public init() {}

    public func renderShape(
        context: inout GraphicsContext,
        node: any NodeProtocol,
        screenPosition: CGPoint,
        zoomScale: CGFloat,
        isSelected: Bool
    ) {
        guard let peopleList = node as? PeopleListNode else {
            // Fallback to circle rendering
            let radius = node.displayRadius * zoomScale
            let circlePath = Circle()
                .path(in: CGRect(
                    x: screenPosition.x - radius,
                    y: screenPosition.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            context.fill(circlePath, with: .color(node.fillColor))
            context.stroke(
                circlePath,
                with: .color(.white.opacity(0.8)),
                lineWidth: isSelected ? 3.0 * zoomScale : 1.5 * zoomScale
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

        // Fill with base color
        context.fill(circlePath, with: .color(node.fillColor))

        // Draw count text centered in node - scaled with zoom
        let count = peopleList.children.count
        let fontSize = max(10, radius * 0.8)  // Scale with node radius
        let countText = Text("\(count)")
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(.white)
        
        context.draw(countText, at: screenPosition, anchor: .center)

        // Stroke outer circle
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
        guard let peopleList = node as? PeopleListNode else {
            return AnyView(
                Circle()
                    .fill(node.fillColor)
                    .frame(
                        width: node.displayRadius * 2 * zoomScale,
                        height: node.displayRadius * 2 * zoomScale
                    )
            )
        }

        return AnyView(
            ZStack {
                // Main circle
                Circle()
                    .fill(peopleList.fillColor)
                    .frame(
                        width: peopleList.displayRadius * 2 * zoomScale,
                        height: peopleList.displayRadius * 2 * zoomScale
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.8), lineWidth: isSelected ? 3 : 1.5)
                    )

                // People icon
                Image(systemName: "person.3.fill")
                    .font(.system(size: peopleList.displayRadius * 0.8 * zoomScale))
                    .foregroundColor(.white)

                // Count badge
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(
                                    width: peopleList.displayRadius * 1.0 * zoomScale,
                                    height: peopleList.displayRadius * 1.0 * zoomScale
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(peopleList.fillColor, lineWidth: 2.0)
                                )
                            
                            Text("\(peopleList.children.count)")
                                .font(.system(size: peopleList.displayRadius * 0.65 * zoomScale, weight: .bold))
                                .foregroundColor(peopleList.fillColor)
                        }
                        .offset(
                            x: peopleList.displayRadius * 0.7 * zoomScale,
                            y: -peopleList.displayRadius * 0.7 * zoomScale
                        )
                    }
                    Spacer()
                }
                .frame(
                    width: peopleList.displayRadius * 2 * zoomScale,
                    height: peopleList.displayRadius * 2 * zoomScale
                )
            }
        )
    }

    public func visualBounds(
        for node: any NodeProtocol,
        at screenPosition: CGPoint,
        zoomScale: CGFloat
    ) -> CGRect {
        let radius = node.displayRadius * zoomScale
        // Include badge in bounds
        let expandedRadius = radius * 1.2
        return CGRect(
            x: screenPosition.x - expandedRadius,
            y: screenPosition.y - expandedRadius,
            width: expandedRadius * 2,
            height: expandedRadius * 2
        )
    }
}
