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

    /// Phase 2C v1 tasks: complete workflow ending with "Serve"
    public static let v1Tasks: [(type: TaskType, minutes: Int, label: String)] = [
        (.plan, 5, "Check Pantry"),
        (.shop, 45, "Shop"),
        (.prep, 20, "Prep"),
        (.cook, 25, "Cook"),
        (.serve, 5, "Serve")
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

        // Create task nodes with linear dependency chain
        var previousTaskID: NodeID?
        
        // Use the same spacing that will be configured for directional layout
        // This ensures nodes start near their target positions, minimizing initial forces
        // Optimized for watchOS screen width (~205pt): 5 tasks * 35pt = 175pt total width
        let configuredSpacing: CGFloat = 35.0  // Match the nodeSpacing set in segment config below

        for (index, scheduledTask) in scheduledTasks.enumerated() {
            // Position nodes according to their depth in the hierarchy
            // Meal is at depth 0, first task at depth 1, etc.
            // Y position will be set by hierarchy layout forces, so use same Y as meal
            let depth = index + 1
            let taskPosition = CGPoint(
                x: position.x + (CGFloat(depth) * configuredSpacing),
                y: position.y  // Same Y as meal - hierarchy forces will adjust
            )

            let task = await model.addTask(
                type: scheduledTask.type,
                estimatedTime: scheduledTask.minutes,
                plannedStart: scheduledTask.plannedStart,
                plannedEnd: scheduledTask.plannedEnd,
                at: taskPosition
            )

            // First task connects to meal via hierarchy edge
            if index == 0 {
                await model.addEdge(from: meal.id, target: task.id, type: .hierarchy)
            }
            
            // All subsequent tasks connect to previous task via hierarchy edge
            // This creates a linear dependency chain: Meal -> Task1 -> Task2 -> Task3 -> Task4 -> Task5
            if let prevID = previousTaskID {
                await model.addEdge(from: prevID, target: task.id, type: .hierarchy)
            }

            previousTaskID = task.id
        }
        
        // Configure directional layout for this segment (default: horizontal)
        // Optimized for watchOS: tighter spacing, stronger forces for quick convergence
        model.setSegmentConfig(
            rootNodeID: meal.id,
            direction: .horizontal,
            strength: 0.9,           // Stronger forces for quicker layout convergence
            nodeSpacing: 35.0        // Tight spacing for watch screen (~205pt wide)
        )

        print("✅ TacoTemplate: Created segment config for meal \(meal.id.uuidString.prefix(8)), direction=horizontal, spacing=35pt, strength=0.9, nodes=6")

        return meal
    }
}
