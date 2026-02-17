//
//  GraphModel+Workflow.swift
//  GraphEditorShared
//
//  Workflow automation extensions for meal planning
//

import Foundation
import CoreGraphics

@available(iOS 16.0, watchOS 9.0, *)
extension GraphModel {

    // MARK: - Workflow Helpers

    /// Find the parent meal node for a given task node
    /// Traverses backwards through hierarchy edges to find the meal
    @MainActor
    public func findMealForTask(_ taskID: NodeID) -> NodeID? {
        var currentID = taskID
        var visited: Set<NodeID> = [taskID]

        // Traverse backwards through hierarchy edges until we find a MealNode
        while true {
            // Check if current node is a MealNode
            if nodes.first(where: { $0.id == currentID })?.unwrapped is MealNode {
                return currentID
            }

            // Find parent hierarchy edge (target -> source direction)
            guard let parentEdge = edges.first(where: {
                $0.target == currentID && $0.type == .hierarchy && !visited.contains($0.from)
            }) else {
                return nil  // No parent found
            }

            visited.insert(parentEdge.from)
            currentID = parentEdge.from
        }
    }

    /// Get all tasks for a meal in hierarchical order
    /// Only follows the top-level chain (meal→shop→prep→cook→…), skipping subtasks
    /// that are stored in a TaskNode's `children` array.
    @MainActor
    public func orderedTasks(for mealID: NodeID) -> [TaskNode] {
        var orderedTasks: [TaskNode] = []
        var visited: Set<NodeID> = [mealID]
        var currentID: NodeID? = mealID

        while let nodeID = currentID {
            // Collect the subtask IDs of the current node so we can skip them
            let subtaskIDs: Set<NodeID>
            if let taskNode = nodes.first(where: { $0.id == nodeID })?.unwrapped as? TaskNode {
                subtaskIDs = Set(taskNode.children)
            } else {
                subtaskIDs = []
            }

            // Find the first hierarchy edge that leads to a non-subtask, unvisited node
            if let edge = edges.first(where: {
                $0.from == nodeID &&
                $0.type == .hierarchy &&
                !visited.contains($0.target) &&
                !subtaskIDs.contains($0.target)
            }) {
                visited.insert(edge.target)
                if let taskNode = nodes.first(where: { $0.id == edge.target })?.unwrapped as? TaskNode {
                    orderedTasks.append(taskNode)
                    currentID = edge.target
                } else {
                    currentID = nil
                }
            } else {
                currentID = nil
            }
        }

        return orderedTasks
    }

    /// Get the current in-progress task for a meal
    @MainActor
    public func currentTask(for mealID: NodeID) -> TaskNode? {
        orderedTasks(for: mealID).first { $0.status == .inProgress }
    }

    /// Get the next pending task after the current one
    @MainActor
    public func nextTask(for mealID: NodeID) -> TaskNode? {
        orderedTasks(for: mealID).first { $0.status == .pending }
    }

    /// Start the workflow by marking the first task as in progress
    @MainActor
    public func startWorkflow(for mealID: NodeID) {
        let tasks = orderedTasks(for: mealID)
        guard let firstTask = tasks.first else { return }
        updateTaskStatus(firstTask.id, to: .inProgress)
    }

    /// Stop the workflow by resetting all tasks to pending
    @MainActor
    public func stopWorkflow(for mealID: NodeID) {
        let tasks = orderedTasks(for: mealID)
        for task in tasks where task.status == .inProgress || task.status == .completed {
            updateTaskStatus(task.id, to: .pending)
        }
    }

    /// Complete current task and optionally auto-advance to next
    @MainActor
    public func completeCurrentTask(for mealID: NodeID, autoAdvance: Bool = true) -> TaskNode? {
        guard let current = currentTask(for: mealID) else { return nil }

        // Complete the current task
        updateTaskStatus(current.id, to: .completed)

        // Auto-advance to next task if enabled
        if autoAdvance, let next = nextTask(for: mealID) {
            updateTaskStatus(next.id, to: .inProgress)
            return next
        }

        return nil
    }

    /// Check if workflow has started (any task is in progress or completed)
    @MainActor
    public func isWorkflowActive(for mealID: NodeID) -> Bool {
        orderedTasks(for: mealID).contains { $0.status == .inProgress || $0.status == .completed }
    }

    /// Get workflow progress as a percentage (0.0 to 1.0)
    @MainActor
    public func workflowProgress(for mealID: NodeID) -> Double {
        let tasks = orderedTasks(for: mealID)
        guard !tasks.isEmpty else { return 0.0 }
        let completedCount = tasks.filter { $0.status == .completed }.count
        return Double(completedCount) / Double(tasks.count)
    }

    /// Check if workflow is complete (all tasks completed)
    @MainActor
    public func isWorkflowComplete(for mealID: NodeID) -> Bool {
        let tasks = orderedTasks(for: mealID)
        return !tasks.isEmpty && tasks.allSatisfy { $0.status == .completed }
    }
}
