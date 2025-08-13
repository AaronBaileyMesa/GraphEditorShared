// Sources/GraphEditorShared/ToggleNode.swift

import SwiftUI
import Foundation

@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public struct ToggleNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = 10.0
    public var isExpanded: Bool = true  // Default to expanded
    public var fillColor: Color { isExpanded ? .green : .red }

    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero, radius: CGFloat = 10.0, isExpanded: Bool = true) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = isExpanded
    }

    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded)
    }

    // In ToggleNode.swift, replace handlingTap with:
    public func handlingTap() -> Self {
        print("ToggleNode \(label) tapped. Expansion state before: \(isExpanded), after: \(!isExpanded)")
        var updated = self
        updated.isExpanded.toggle()
        return updated
    }

    // Override: Custom draw with +/- icon
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
        let scaledRadius = radius * zoomScale
        let borderWidth: CGFloat = isSelected ? 4 * zoomScale : 0
        let borderRadius = scaledRadius + borderWidth / 2

        if borderWidth > 0 {
            let borderPath = Path(ellipseIn: CGRect(x: position.x - borderRadius, y: position.y - borderRadius, width: 2 * borderRadius, height: 2 * borderRadius))
            context.stroke(borderPath, with: .color(.yellow), lineWidth: borderWidth)
        }

        let innerPath = Path(ellipseIn: CGRect(x: position.x - scaledRadius, y: position.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius))
        context.fill(innerPath, with: .color(fillColor))  // Use self.fillColor (e.g., .green if expanded, .red if collapsed)
        
        // Draw +/- icon
        let iconText = isExpanded ? "-" : "+"
        let fontSize = max(8.0, 12.0 * zoomScale)  // Readable min size
        let text = Text(iconText).foregroundColor(.white).font(.system(size: fontSize, weight: .bold))
        let resolved = context.resolve(text)
        context.draw(resolved, at: position, anchor: .center)  // Center in node

        // Draw label above (as in protocol default)
        let labelFontSize = max(8.0, 12.0 * zoomScale)
        let labelText = Text("\(label)").foregroundColor(.white).font(.system(size: labelFontSize))
        let labelResolved = context.resolve(labelText)
        let labelPosition = CGPoint(x: position.x, y: position.y - (scaledRadius + 10 * zoomScale))
        context.draw(labelResolved, at: labelPosition, anchor: .center)
    }

    // Codable conformance (for persistence)
    enum CodingKeys: String, CodingKey {
        case id, label, radius, isExpanded
        case positionX, positionY
        case velocityX, velocityY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? 10.0
        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
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
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
    }
}
