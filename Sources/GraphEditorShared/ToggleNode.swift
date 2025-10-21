//
//  ToggleNode.swift
//  GraphEditorShared
//
//  Created by handcart on [date]; updated for completeness.
//

import SwiftUI
import Foundation

@available(iOS 16.0, *)
@available(watchOS 9.0, *)
public struct ToggleNode: NodeProtocol, Equatable {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = Constants.App.nodeModelRadius  // Use constant for consistency
    public var isExpanded: Bool = true
    public var contents: [NodeContent] = []  // NEW: Ordered list, default empty
    public var fillColor: Color { isExpanded ? .green : .red }

    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero, radius: CGFloat = Constants.App.nodeModelRadius, isExpanded: Bool = true, contents: [NodeContent] = []) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = isExpanded
        self.contents = contents
    }

    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents)
    }

    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents)
    }

    public func handlingTap() -> Self {
        var updated = self
        updated.isExpanded.toggle()
        updated.velocity = .zero  // Reset to prevent immediate jumps
        return updated
    }
    
    public func shouldHideChildren() -> Bool {
        !isExpanded
    }
    
    @available(iOS 16.0, *)
    @available(watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(Circle().fill(fillColor).frame(width: radius * 2 * zoomScale, height: radius * 2 * zoomScale))  // Simple default
    }

    @available(iOS 16.0, *)
    @available(watchOS 9.0, *)
    public func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
        let scaledRadius = radius * zoomScale
        let borderWidth: CGFloat = isSelected ? max(3.0, 4 * zoomScale) : 0
        let borderRadius = scaledRadius + borderWidth / 2

        // Draw border if selected
        if borderWidth > 0 {
            let borderPath = Path(ellipseIn: CGRect(x: position.x - borderRadius, y: position.y - borderRadius, width: 2 * borderRadius, height: 2 * borderRadius))
            context.stroke(borderPath, with: .color(.yellow), lineWidth: borderWidth)
        }

        // Draw node circle
        let innerPath = Path(ellipseIn: CGRect(x: position.x - scaledRadius, y: position.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius))
        context.fill(innerPath, with: .color(fillColor))

        // Draw +/- icon centered in node
        let iconText = isExpanded ? "-" : "+"
        let iconFontSize = max(8.0, 12.0 * zoomScale)
        let iconResolved = context.resolve(Text(iconText).foregroundColor(.white).font(.system(size: iconFontSize, weight: .bold)))
        context.draw(iconResolved, at: position, anchor: .center)

        // Draw label above node
        let labelFontSize = max(8.0, 12.0 * zoomScale)
        let labelResolved = context.resolve(Text("\(label)").foregroundColor(.white).font(.system(size: labelFontSize)))
        let labelPosition = CGPoint(x: position.x, y: position.y - (scaledRadius + 10 * zoomScale))
        context.draw(labelResolved, at: labelPosition, anchor: .center)

        // TEMP: Placeholder for contents list drawing (full impl in Step 3)
        if !contents.isEmpty && zoomScale > 0.5 {
            // Add drawing code later
        }
    }

    // Codable conformance (updated for contents array)
    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius, isExpanded, contents  // Updated key
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decode(CGFloat.self, forKey: .radius)
        isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        contents = try container.decode([NodeContent].self, forKey: .contents)  // NEW: Decode array
        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)
        let velX = try container.decode(CGFloat.self, forKey: .velocityX)
        let velY = try container.decode(CGFloat.self, forKey: .velocityY)
        velocity = CGPoint(x: velX, y: velY)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(radius, forKey: .radius)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(contents, forKey: .contents)  // NEW: Encode array
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
    }

    public static func == (lhs: ToggleNode, rhs: ToggleNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.label == rhs.label &&
        lhs.position == rhs.position &&
        lhs.velocity == rhs.velocity &&
        lhs.radius == rhs.radius &&
        lhs.isExpanded == rhs.isExpanded &&
        lhs.contents == rhs.contents  // Updated for array
    }
}
