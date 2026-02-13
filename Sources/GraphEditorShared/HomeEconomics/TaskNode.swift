//
//  TaskNode.swift
//  GraphEditorShared
//
//  Represents a work task with status tracking
//

import SwiftUI
import Foundation

/// Represents a task (e.g., "Shop for ingredients", "Cook meal")
@available(iOS 16.0, watchOS 9.0, *)
public struct TaskNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Subtasks (optional)
    public var childOrder: [NodeID]

    // Task-specific properties
    public let taskType: TaskType
    public var status: TaskStatus        // Mutable - changes as work progresses
    public let estimatedTime: Int        // minutes (estimated)
    public var actualTime: Int?          // minutes (actual, nil until completed)
    public let assignedUserID: NodeID?

    // Timestamp fields for workflow tracking
    public var plannedStart: Date?
    public var plannedEnd: Date?
    public var startedAt: Date?
    public var completedAt: Date?

    public var displayRadius: CGFloat {
        radius * 1.1
    }

    public var fillColor: Color {
        switch status {
        case .pending: return .gray
        case .inProgress: return .yellow
        case .completed: return .green
        case .skipped: return .red
        case .blocked: return .orange
        case .declined: return .red.opacity(0.6)
        }
    }

    public var contents: [NodeContent] {
        get {
            var result: [NodeContent] = [
                .string(taskType.rawValue),
                .string(status.rawValue)
            ]
            if let actual = actualTime {
                result.append(.number(Double(actual)))
            }
            return result
        }
        set {
            _ = newValue  // Contents are read-only
        }
    }

    // MARK: - Initializers

    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = Constants.App.nodeModelRadius,
        taskType: TaskType,
        status: TaskStatus = .pending,
        estimatedTime: Int,
        actualTime: Int? = nil,
        assignedUserID: NodeID? = nil,
        plannedStart: Date? = nil,
        plannedEnd: Date? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.taskType = taskType
        self.status = status
        self.estimatedTime = estimatedTime
        self.actualTime = actualTime
        self.assignedUserID = assignedUserID
        self.plannedStart = plannedStart
        self.plannedEnd = plannedEnd
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.isExpanded = true
        self.isCollapsible = true  // Can collapse to hide subtasks
        self.children = []
        self.childOrder = []
    }

    // MARK: - Task Status Helpers

    /// Update task to completed status with actual time spent
    public func completing(timeSpent: Int) -> Self {
        var updated = self
        updated.status = .completed
        updated.actualTime = timeSpent
        updated.completedAt = Date()
        return updated
    }

    /// Update task to in-progress status
    public func startingWork() -> Self {
        var updated = self
        updated.status = .inProgress
        updated.startedAt = Date()
        return updated
    }

    /// Update task to skipped status
    public func skipping() -> Self {
        var updated = self
        updated.status = .skipped
        return updated
    }

    /// Update task to blocked status
    public func blocking() -> Self {
        var updated = self
        updated.status = .blocked
        return updated
    }

    /// Update task to declined status
    public func declining() -> Self {
        var updated = self
        updated.status = .declined
        return updated
    }

    // MARK: - NodeProtocol Requirements

    public func with(position: CGPoint, velocity: CGPoint) -> Self {
        var updated = self
        updated.position = position
        updated.velocity = velocity
        return updated
    }

    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> Self {
        var updated = self
        updated.position = position
        updated.velocity = velocity
        // Note: taskType and estimatedTime are immutable
        // Status and actualTime changes should go through helper methods
        return updated
    }

    public func with(children: [NodeID]) -> Self {
        var updated = self
        updated.children = children
        return updated
    }

    public func with(childOrder: [NodeID]) -> Self {
        var updated = self
        updated.childOrder = childOrder
        return updated
    }

    public func with(isExpanded: Bool) -> Self {
        var updated = self
        updated.isExpanded = isExpanded
        return updated
    }

    public func shouldHideChildren() -> Bool {
        isCollapsible && !isExpanded
    }

    public func handlingTap() -> Self {
        guard isCollapsible else { return self }
        var updated = self
        updated.isExpanded.toggle()
        updated.velocity = .zero
        return updated
    }

    public mutating func collapse() {
        isExpanded = false
    }

    public mutating func bulkCollapse() {
        isExpanded = false
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, radius
        case taskType, status, estimatedTime, actualTime, assignedUserID
        case plannedStart, plannedEnd, startedAt, completedAt
        case isExpanded, isCollapsible, children, childOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        radius = try container.decodeIfPresent(CGFloat.self, forKey: .radius) ?? Constants.App.nodeModelRadius

        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)

        taskType = try container.decode(TaskType.self, forKey: .taskType)
        status = try container.decode(TaskStatus.self, forKey: .status)
        estimatedTime = try container.decode(Int.self, forKey: .estimatedTime)
        actualTime = try container.decodeIfPresent(Int.self, forKey: .actualTime)
        assignedUserID = try container.decodeIfPresent(NodeID.self, forKey: .assignedUserID)

        plannedStart = try container.decodeIfPresent(Date.self, forKey: .plannedStart)
        plannedEnd = try container.decodeIfPresent(Date.self, forKey: .plannedEnd)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)

        isExpanded = try container.decodeIfPresent(Bool.self, forKey: .isExpanded) ?? true
        isCollapsible = try container.decodeIfPresent(Bool.self, forKey: .isCollapsible) ?? true
        children = try container.decodeIfPresent([NodeID].self, forKey: .children) ?? []
        childOrder = try container.decodeIfPresent([NodeID].self, forKey: .childOrder) ?? []

        self.velocity = .zero
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(radius, forKey: .radius)
        try container.encode(taskType, forKey: .taskType)
        try container.encode(status, forKey: .status)
        try container.encode(estimatedTime, forKey: .estimatedTime)
        try container.encodeIfPresent(actualTime, forKey: .actualTime)
        try container.encodeIfPresent(assignedUserID, forKey: .assignedUserID)
        try container.encodeIfPresent(plannedStart, forKey: .plannedStart)
        try container.encodeIfPresent(plannedEnd, forKey: .plannedEnd)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)
    }
}

// MARK: - Equatable
@available(iOS 16.0, watchOS 9.0, *)
extension TaskNode {
    public static func == (lhs: TaskNode, rhs: TaskNode) -> Bool {
        lhs.id == rhs.id && lhs.taskType == rhs.taskType && lhs.status == rhs.status
    }
}
