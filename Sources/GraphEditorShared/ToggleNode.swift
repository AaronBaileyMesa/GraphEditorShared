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
public struct ToggleNode: NodeProtocol, HierarchicalNode, Equatable {  // Updated: Added HierarchicalNode
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = Constants.App.nodeModelRadius  // Use constant for consistency
    public var isExpanded: Bool = true
    public var contents: [NodeContent] = []  // NEW: Ordered list, default empty
    public var fillColor: Color { isExpanded ? .green : .red }
    public var children: [NodeID] = []
    public var childOrder: [NodeID] = []  // NEW: Explicit order for children (defaults to children array order)

    public init(id: NodeID = NodeID(), label: Int, position: CGPoint, velocity: CGPoint = .zero, radius: CGFloat = Constants.App.nodeModelRadius, isExpanded: Bool = true, contents: [NodeContent] = [], children: [NodeID] = [], childOrder: [NodeID]? = nil) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = isExpanded
        self.contents = contents
        self.children = children
        // Validate childOrder to be a permutation of children
        let validatedOrder = (childOrder ?? children).filter { children.contains($0) }
        self.childOrder = validatedOrder.isEmpty ? children : validatedOrder
    }

    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents, children: children, childOrder: childOrder)
    }

    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents, children: children, childOrder: childOrder)
    }

    public func handlingTap() -> Self {
        var updated = self
        updated.collapse()  // Reuse protocol method
        updated.velocity = .zero  // Reset to prevent immediate jumps
        return updated
    }
    
    public func with(children: [NodeID]) -> Self {
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents, children: children, childOrder: childOrder)
    }

    public func with(childOrder: [NodeID]) -> Self {  // NEW: Method to update order independently
        ToggleNode(id: id, label: label, position: position, velocity: velocity, radius: radius, isExpanded: isExpanded, contents: contents, children: children, childOrder: childOrder)
    }

    public func shouldHideChildren() -> Bool {
        !isExpanded  // Existing, but could recurse if deep trees
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

        // NEW: Draw contents list vertically below node
        if !contents.isEmpty && zoomScale > 0.5 {  // Only if zoomed
            var yOffset = scaledRadius + 5 * zoomScale  // Start below node
            let contentFontSize = max(6.0, 8.0 * zoomScale)
            let maxItems = 3  // Limit for watchOS
            for content in contents.prefix(maxItems) {
                let contentText = Text(content.displayText).font(.system(size: contentFontSize)).foregroundColor(.gray)
                let resolved = context.resolve(contentText)
                let contentPosition = CGPoint(x: position.x, y: position.y + yOffset)
                context.draw(resolved, at: contentPosition, anchor: .center)
                yOffset += 10 * zoomScale  // Line spacing
            }
            if contents.count > maxItems {
                let moreText = Text("+\(contents.count - maxItems) more").font(.system(size: contentFontSize * 0.75)).foregroundColor(.gray)
                let resolved = context.resolve(moreText)
                context.draw(resolved, at: CGPoint(x: position.x, y: position.y + yOffset), anchor: .center)
            }
        }
    }

    // NEW: HierarchicalNode methods
    public mutating func collapse() {
        isExpanded = false
    }
    
    public mutating func bulkCollapse() {
        isExpanded = false
        // Recursion handled in GraphModel for full graph access
    }

    // Codable conformance (updated for contents array and childOrder)
    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius, isExpanded, contents, children, childOrder  // UPDATED: Added children and childOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decode(CGFloat.self, forKey: .radius)
        isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        contents = try container.decode([NodeContent].self, forKey: .contents)  // NEW: Decode array
        children = try container.decode([NodeID].self, forKey: .children)  // NEW: Decode children
        childOrder = try container.decodeIfPresent([NodeID].self, forKey: .childOrder) ?? []  // NEW: Decode childOrder (optional fallback to empty)
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
        try container.encode(children, forKey: .children)  // NEW: Encode children
        try container.encode(childOrder, forKey: .childOrder)  // NEW: Encode childOrder
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
        lhs.contents == rhs.contents &&
        lhs.children == rhs.children &&  // UPDATED: Include children
        lhs.childOrder == rhs.childOrder  // UPDATED: Include childOrder
    }
}
