//
//  TableNode.swift
//  GraphEditorShared
//
//  Represents a dining table with configurable seating positions
//

import SwiftUI
import Foundation

/// Represents a dining table with assigned seating
@available(iOS 16.0, watchOS 9.0, *)
public struct TableNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Person nodes seated at this table
    public var childOrder: [NodeID]

    // Table-specific properties
    public let name: String
    public let headSeats: Int  // Number of seats at head/foot (usually 1-2)
    public let sideSeats: Int  // Number of seats on each long side (usually 2-4)
    public let tableLength: CGFloat  // Visual length of the table
    public let tableWidth: CGFloat   // Visual width of the table

    // Seating assignments (seat index -> person node ID)
    // Seat indices: 0 = head, (totalSeats-1) = foot, 1...n = sides
    public var seatingAssignments: [Int: NodeID]

    /// Total number of seats at the table
    public var totalSeats: Int {
        headSeats * 2 + sideSeats * 2
    }

    public var displayRadius: CGFloat {
        // Table is rendered as a rectangle, not a circle
        max(tableLength, tableWidth) / 2
    }

    public var fillColor: Color {
        .brown
    }

    public var contents: [NodeContent] {
        get {
            [.string(name), .string("\(totalSeats) seats")]
        }
        set {
            _ = newValue  // Contents are read-only for TableNode
        }
    }

    // MARK: - Initializers

    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = 20.0,
        name: String,
        headSeats: Int = 1,
        sideSeats: Int = 3,
        tableLength: CGFloat = 50.0,
        tableWidth: CGFloat = 30.0,
        seatingAssignments: [Int: NodeID] = [:]
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = true
        self.isCollapsible = false
        self.children = []
        self.childOrder = []
        self.name = name
        self.headSeats = headSeats
        self.sideSeats = sideSeats
        self.tableLength = tableLength
        self.tableWidth = tableWidth
        self.seatingAssignments = seatingAssignments
    }

    // MARK: - Seat Position Calculation

    /// Get the position offset for a specific seat relative to the table center
    /// - Parameters:
    ///   - seatIndex: Seat index (0-11) where 0 = head, last index = foot, others = sides
    /// - Returns: Position offset from table center
    public func seatOffset(for seatIndex: Int) -> CGPoint {
        // Calculate offsets to position person nodes at the table edge
        // Seated person nodes are scaled to 24pt diameter (12pt radius) to represent ~2 feet per person
        // Using a negative gap to make person nodes overlap the table edge like chairs
        // Target: 1/3 of radius (4pt) overlapping the table edge
        let personRadius: CGFloat = 12.0  // 24 inches diameter for seated persons
        let overlapAmount: CGFloat = 4.0  // 1/3 of 12pt radius
        let gapFromTable: CGFloat = -overlapAmount

        // Table rendering: width=X-axis (horizontal), length=Y-axis (vertical)
        // Head/foot seats have Y-offset → need to clear tableLength in Y-direction
        // Left/right seats have X-offset → need to clear tableWidth in X-direction
        let headFootOffset = tableLength / 2 + personRadius + gapFromTable
        let leftRightOffset = tableWidth / 2 + personRadius + gapFromTable

        #if DEBUG
        print("🪑 TableNode seatOffset: seatIndex=\(seatIndex), tableWidth=\(tableWidth), tableLength=\(tableLength)")
        print("   headFootOffset=\(headFootOffset) (tableLength/2=\(tableLength/2) + personRadius=\(personRadius) + gap=\(gapFromTable))")
        print("   leftRightOffset=\(leftRightOffset) (tableWidth/2=\(tableWidth/2) + personRadius=\(personRadius) + gap=\(gapFromTable))")
        #endif

        // Seating layout: index 0 = head, last index = foot, remaining indices alternate left/right sides
        let lastIndex = totalSeats - 1
        
        // Head seat (index 0)
        if seatIndex == 0 {
            return CGPoint(x: 0, y: -headFootOffset)
        }
        
        // Foot seat (last index)
        if seatIndex == lastIndex {
            return CGPoint(x: 0, y: headFootOffset)
        }
        
        // Side seats: indices 1 through (lastIndex - 1)
        // Distribute evenly along left and right sides
        let sideSeatsCount = totalSeats - 2  // Exclude head and foot
        let seatsPerSide = sideSeatsCount / 2
        let sideIndex = seatIndex - 1  // 0-based for side calculation
        
        // Even indices (1, 3, 5...) = left side, odd indices (2, 4, 6...) = right side
        let isLeftSide = (sideIndex % 2 == 0)
        let positionOnSide = sideIndex / 2  // 0, 1, 2... position along the side
        
        // Calculate Y offset: distribute evenly along table length
        let seatSpacing = tableLength / CGFloat(seatsPerSide + 1)
        let yOffset = -tableLength / 2 + seatSpacing * CGFloat(positionOnSide + 1)
        
        // X offset: left or right side
        let xOffset = isLeftSide ? -leftRightOffset : leftRightOffset
        
        return CGPoint(x: xOffset, y: yOffset)
    }

    /// Get the absolute position for a specific seat
    public func seatPosition(for seatIndex: Int) -> CGPoint {
        let offset = seatOffset(for: seatIndex)
        return CGPoint(x: self.position.x + offset.x, y: self.position.y + offset.y)
    }

    // MARK: - NodeProtocol Methods

    public func with(position: CGPoint, velocity: CGPoint) -> TableNode {
        TableNode(
            id: id,
            label: label,
            position: position,
            velocity: velocity,
            radius: radius,
            name: name,
            headSeats: headSeats,
            sideSeats: sideSeats,
            tableLength: tableLength,
            tableWidth: tableWidth,
            seatingAssignments: seatingAssignments
        )
    }

    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> TableNode {
        // TableNode doesn't support modifying via contents
        with(position: position, velocity: velocity)
    }

    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(
            ZStack {
                // Table surface
                RoundedRectangle(cornerRadius: 8 * zoomScale)
                    .fill(fillColor.opacity(0.3))
                    .frame(width: tableWidth * zoomScale, height: tableLength * zoomScale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8 * zoomScale)
                            .stroke(fillColor, lineWidth: 2 * zoomScale)
                    )

                // Table label
                Text("\(label)")
                    .font(.system(size: 12 * zoomScale))
                    .foregroundColor(.white)
            }
        )
    }

    public func handlingTap() -> TableNode {
        self
    }

    public func shouldHideChildren() -> Bool {
        false
    }

    public mutating func collapse() {
        // TableNode doesn't collapse
    }

    public mutating func bulkCollapse() {
        // TableNode doesn't collapse
    }

    public var mass: CGFloat {
        30.0  // Heavier than regular nodes
    }

    public var isVisible: Bool {
        true
    }

    // MARK: - Type Descriptor

    public var typeDescriptor: NodeTypeDescriptor {
        TableNodeDescriptor(node: self)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius
        case isExpanded, isCollapsible, children, childOrder
        case name, headSeats, sideSeats, tableLength, tableWidth, seatingAssignments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)

        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)

        let velX = try container.decode(CGFloat.self, forKey: .velocityX)
        let velY = try container.decode(CGFloat.self, forKey: .velocityY)
        velocity = CGPoint(x: velX, y: velY)

        radius = try container.decode(CGFloat.self, forKey: .radius)
        isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        isCollapsible = try container.decode(Bool.self, forKey: .isCollapsible)
        children = try container.decode([NodeID].self, forKey: .children)
        childOrder = try container.decode([NodeID].self, forKey: .childOrder)

        name = try container.decode(String.self, forKey: .name)
        headSeats = try container.decode(Int.self, forKey: .headSeats)
        sideSeats = try container.decode(Int.self, forKey: .sideSeats)
        tableLength = try container.decode(CGFloat.self, forKey: .tableLength)
        tableWidth = try container.decode(CGFloat.self, forKey: .tableWidth)
        seatingAssignments = try container.decode([Int: NodeID].self, forKey: .seatingAssignments)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
        try container.encode(radius, forKey: .radius)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)

        try container.encode(name, forKey: .name)
        try container.encode(headSeats, forKey: .headSeats)
        try container.encode(sideSeats, forKey: .sideSeats)
        try container.encode(tableLength, forKey: .tableLength)
        try container.encode(tableWidth, forKey: .tableWidth)
        try container.encode(seatingAssignments, forKey: .seatingAssignments)
    }
}
