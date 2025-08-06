import Foundation
import SwiftUI

@available(iOS 13.0, *)
@available(watchOS 9.0, *)
public struct ToggleNode: NodeProtocol {
    public let id: NodeID
    public var label: Int
    public var position: CGPoint
    public var velocity: CGPoint = .zero
    public var radius: CGFloat = 10.0
    public var isExpanded: Bool = true  // Default expanded (green, children visible)
    
    public init(id: NodeID = UUID(), label: Int, position: CGPoint, velocity: CGPoint = .zero, radius: CGFloat = 10.0, isExpanded: Bool = true) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = isExpanded
    }
    
    // Codable conformance (for persistence in Step 3)
    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius, isExpanded
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try container.decode(NodeID.self, forKey: .id)
        let decodedLabel = try container.decode(Int.self, forKey: .label)
        let decodedRadius = try container.decode(CGFloat.self, forKey: .radius)
        let decodedIsExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        let decodedPosition = CGPoint(x: posX, y: posY)
        let velX = try container.decode(CGFloat.self, forKey: .velocityX)
        let velY = try container.decode(CGFloat.self, forKey: .velocityY)
        let decodedVelocity = CGPoint(x: velX, y: velY)
        
        self.init(id: decodedID, label: decodedLabel, position: decodedPosition, velocity: decodedVelocity, radius: decodedRadius, isExpanded: decodedIsExpanded)
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
    
    // Equatable (manual, since protocol requires it)
    public static func == (lhs: ToggleNode, rhs: ToggleNode) -> Bool {
        lhs.id == rhs.id && lhs.label == rhs.label && lhs.position == rhs.position &&
        lhs.velocity == rhs.velocity && lhs.radius == rhs.radius && lhs.isExpanded == rhs.isExpanded
    }
    
    // Overrides
    @available(iOS 13.0, *)
    @available(watchOS 9.0, *)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        let color = isExpanded ? Color.green : Color.red
        let scaledRadius = radius * zoomScale
        let borderWidth: CGFloat = isSelected ? 4 * zoomScale : 0
        let borderRadius = scaledRadius + borderWidth / 2
        
        return AnyView(
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 2 * scaledRadius, height: 2 * scaledRadius)
                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: borderWidth)
                        .frame(width: 2 * borderRadius, height: 2 * borderRadius)
                }
                Text("\(label)")
                    .foregroundColor(.white)
                    .font(.system(size: UIFontMetrics.default.scaledValue(for: 12) * zoomScale))
            }
        )
    }
    
    @available(iOS 13.0, *)
    @available(watchOS 9.0, *)
    public func handlingTap() -> Self {
        var mutated = self
        mutated.isExpanded.toggle()
        return mutated
    }
    
    @available(iOS 13.0, *)
    @available(watchOS 9.0, *)
    public func shouldHideChildren() -> Bool {
        !isExpanded
    }
    
    @available(iOS 15.0, *)
    @available(watchOS 9.0, *)
    public func draw(in context: GraphicsContext, at position: CGPoint, zoomScale: CGFloat, isSelected: Bool) {
        let color = isExpanded ? Color.green : Color.red
        let scaledRadius = radius * zoomScale
        let borderWidth: CGFloat = isSelected ? 4 * zoomScale : 0
        let borderRadius = scaledRadius + borderWidth / 2
        
        // Draw filled circle with custom color
        context.fill(Path(ellipseIn: CGRect(x: position.x - scaledRadius, y: position.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius)), with: .color(color))
        
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
}
