//
//  TacoTemplateBuilder.swift
//  GraphEditorShared
//
//  Template builder for taco dinner workflow
//

import Foundation
import CoreGraphics

/// Builds a complete taco dinner graph with tasks and timing
@available(iOS 16.0, watchOS 9.0, *)
public struct TacoTemplateBuilder {

    // MARK: - Task Definitions (v1)

    /// Phase 2C v1 tasks: ends at "Ready to Cook"
    public static let v1Tasks: [(type: TaskType, minutes: Int, label: String)] = [
        (.plan, 5, "Check Pantry"),
        (.shop, 45, "Shop"),
        (.prep, 20, "Prep"),
        (.cook, 25, "Cook")
    ]

    // MARK: - Schedule Calculation

    /// Calculate planned start and end times for each task, working backward from dinner time
    public static func calculateSchedule(
        dinnerTime: Date,
        tasks: [(type: TaskType, minutes: Int, label: String)]
    ) -> [(type: TaskType, minutes: Int, label: String, plannedStart: Date, plannedEnd: Date)] {
        var result: [(type: TaskType, minutes: Int, label: String, plannedStart: Date, plannedEnd: Date)] = []
        var currentEndTime = dinnerTime

        // Work backward from dinner time
        for task in tasks.reversed() {
            let plannedEnd = currentEndTime
            let plannedStart = Calendar.current.date(byAdding: .minute, value: -task.minutes, to: plannedEnd)!

            result.insert((
                type: task.type,
                minutes: task.minutes,
                label: task.label,
                plannedStart: plannedStart,
                plannedEnd: plannedEnd
            ), at: 0)

            currentEndTime = plannedStart
        }

        return result
    }

    // MARK: - Graph Building

    /// Build a complete taco dinner graph with meal node and task nodes
    @MainActor
    public static func buildGraph(
        in model: GraphModel,
        guests: Int,
        dinnerTime: Date,
        protein: ProteinType,
        at position: CGPoint
    ) async -> MealNode {
        // Calculate task schedule
        let scheduledTasks = calculateSchedule(dinnerTime: dinnerTime, tasks: v1Tasks)

        // Create meal node
        let mealName = "\(protein.rawValue.capitalized) Tacos"
        let meal = await model.addMeal(
            name: mealName,
            date: dinnerTime,
            mealType: .dinner,
            servings: guests,
            guests: guests,
            dinnerTime: dinnerTime,
            protein: protein,
            at: position
        )

        // Create task nodes with hierarchy and precedes edges
        var previousTaskID: NodeID?
        let taskSpacing: CGFloat = 120

        for (index, scheduledTask) in scheduledTasks.enumerated() {
            let taskPosition = CGPoint(
                x: position.x + (CGFloat(index) * taskSpacing),
                y: position.y + 80
            )

            let task = await model.addTask(
                type: scheduledTask.type,
                estimatedTime: scheduledTask.minutes,
                plannedStart: scheduledTask.plannedStart,
                plannedEnd: scheduledTask.plannedEnd,
                at: taskPosition
            )

            // Add hierarchy edge from meal to task
            await model.addEdge(from: meal.id, target: task.id, type: .hierarchy)

            // Add precedes edge from previous task to current task
            if let prevID = previousTaskID {
                await model.addEdge(from: prevID, target: task.id, type: .precedes)
            }

            previousTaskID = task.id
        }

        return meal
    }
}
