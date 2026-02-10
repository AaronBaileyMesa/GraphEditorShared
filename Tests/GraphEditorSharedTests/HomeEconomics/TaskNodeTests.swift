//
//  TaskNodeTests.swift
//  GraphEditorSharedTests
//
//  Tests for TaskNode conformance to NodeProtocol
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

@available(iOS 16.0, watchOS 9.0, *)
struct TaskNodeTests {

    @Test("TaskNode initializes with correct properties")
    func testInitialization() {
        let task = TaskNode(
            label: 1,
            position: CGPoint(x: 100, y: 200),
            taskType: .shop,
            status: .pending,
            estimatedTime: 30,
            assignedUserID: UUID()
        )

        #expect(task.label == 1)
        #expect(task.taskType == .shop)
        #expect(task.status == .pending)
        #expect(task.estimatedTime == 30)
        #expect(task.actualTime == nil)
        #expect(task.assignedUserID != nil)
        #expect(task.isCollapsible == true)
    }

    @Test("TaskNode fill color changes by status")
    func testFillColorByStatus() {
        let pending = TaskNode(
            label: 1, position: .zero, taskType: .cook,
            status: .pending, estimatedTime: 20
        )
        let inProgress = TaskNode(
            label: 2, position: .zero, taskType: .cook,
            status: .inProgress, estimatedTime: 20
        )
        let completed = TaskNode(
            label: 3, position: .zero, taskType: .cook,
            status: .completed, estimatedTime: 20
        )
        let skipped = TaskNode(
            label: 4, position: .zero, taskType: .cook,
            status: .skipped, estimatedTime: 20
        )

        #expect(pending.fillColor == .gray)
        #expect(inProgress.fillColor == .yellow)
        #expect(completed.fillColor == .green)
        #expect(skipped.fillColor == .red)
    }

    @Test("TaskNode completing() updates status and actualTime")
    func testCompleting() {
        let task = TaskNode(
            label: 1, position: .zero, taskType: .prep,
            status: .inProgress, estimatedTime: 15
        )

        let completed = task.completing(timeSpent: 18)

        #expect(completed.status == .completed)
        #expect(completed.actualTime == 18)
        #expect(completed.taskType == task.taskType)  // Other properties preserved
    }

    @Test("TaskNode startingWork() changes status to inProgress")
    func testStartingWork() {
        let task = TaskNode(
            label: 1, position: .zero, taskType: .cleanup,
            status: .pending, estimatedTime: 10
        )

        let started = task.startingWork()

        #expect(started.status == .inProgress)
        #expect(started.actualTime == nil)  // Not completed yet
    }

    @Test("TaskNode skipping() changes status to skipped")
    func testSkipping() {
        let task = TaskNode(
            label: 1, position: .zero, taskType: .serve,
            status: .pending, estimatedTime: 5
        )

        let skipped = task.skipping()

        #expect(skipped.status == .skipped)
    }

    @Test("TaskNode is Codable with optional actualTime")
    func testCodable() throws {
        let original = TaskNode(
            id: UUID(),
            label: 5,
            position: CGPoint(x: 50, y: 100),
            taskType: .cook,
            status: .completed,
            estimatedTime: 45,
            actualTime: 50,
            assignedUserID: UUID()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskNode.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.label == original.label)
        #expect(decoded.taskType == original.taskType)
        #expect(decoded.status == original.status)
        #expect(decoded.estimatedTime == original.estimatedTime)
        #expect(decoded.actualTime == original.actualTime)
        #expect(decoded.assignedUserID == original.assignedUserID)
        #expect(decoded.velocity == .zero)  // Velocity reset on decode
    }

    @Test("TaskNode without actualTime encodes/decodes correctly")
    func testCodableWithoutActualTime() throws {
        let original = TaskNode(
            label: 1, position: .zero, taskType: .plan,
            status: .pending, estimatedTime: 10
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TaskNode.self, from: encoded)

        #expect(decoded.actualTime == nil)
        #expect(decoded.status == .pending)
    }

    @Test("TaskNode works with AnyNode wrapper")
    func testAnyNodeWrapping() {
        let task = TaskNode(
            label: 1, position: .zero, taskType: .shop,
            status: .inProgress, estimatedTime: 30
        )

        let anyNode = AnyNode(task)
        #expect(anyNode.id == task.id)
        #expect(anyNode.label == task.label)
        #expect(anyNode.fillColor == .yellow)  // In progress

        // Test unwrapping
        if let unwrapped = anyNode.unwrapped as? TaskNode {
            #expect(unwrapped.taskType == .shop)
            #expect(unwrapped.status == .inProgress)
        } else {
            Issue.record("Failed to unwrap TaskNode")
        }
    }

    @Test("TaskNode contents include type and status")
    func testContents() {
        let task = TaskNode(
            label: 1, position: .zero, taskType: .cook,
            status: .completed, estimatedTime: 25, actualTime: 28
        )

        #expect(task.contents.count == 3)  // type, status, actualTime

        // Verify taskType
        if case .string(let value) = task.contents[0] {
            #expect(value == "cook")
        } else {
            Issue.record("Expected string content for taskType")
        }

        // Verify status
        if case .string(let value) = task.contents[1] {
            #expect(value == "completed")
        } else {
            Issue.record("Expected string content for status")
        }

        // Verify actualTime
        if case .number(let value) = task.contents[2] {
            #expect(value == 28.0)
        } else {
            Issue.record("Expected number content for actualTime")
        }
    }
}
