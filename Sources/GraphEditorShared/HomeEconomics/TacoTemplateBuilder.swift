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
        // Begin bulk operation to prevent simulation from running during construction
        await model.beginBulkOperation()

        // Calculate task schedule
        let scheduledTasks = calculateSchedule(dinnerTime: dinnerTime, tasks: v1Tasks)

        // Calculate initial positions to match directional layout targets
        // This minimizes initial displacement and speeds up convergence
        let preferredSpacing: CGFloat = 35.0  // Desired spacing between nodes
        let maxDepth = v1Tasks.count  // 5 tasks = max depth of 5 (meal is depth 0)

        // Simulation bounds for Apple Watch: ~205pt wide
        let simulationWidth: CGFloat = 205.0
        let margin: CGFloat = 20.0

        // Match DirectionalLayoutCalculator's dynamic spacing calculation
        // It uses 80% of width for horizontal layouts
        let availableSpace = simulationWidth * 0.8  // 164pt
        let totalNeeded = CGFloat(maxDepth) * preferredSpacing  // 175pt

        // Apply same compression logic as DirectionalLayoutCalculator
        let actualSpacing: CGFloat
        if totalNeeded > availableSpace {
            // Compress spacing to fit
            actualSpacing = availableSpace / CGFloat(maxDepth)  // 164 / 5 = 32.8pt
        } else {
            actualSpacing = preferredSpacing  // 35pt
        }

        // Calculate total extent with actual spacing
        let totalExtent = CGFloat(maxDepth) * actualSpacing
        let availableWidth = simulationWidth - (2 * margin)  // 165pt

        // Calculate anchor (where depth 0 = meal node should be positioned)
        let anchorX: CGFloat
        if totalExtent < availableWidth {
            // Segment fits - center it
            anchorX = margin + (availableWidth - totalExtent) / 2.0
        } else {
            // Segment is wide - start from margin
            anchorX = margin  // 20pt
        }

        // Create meal node at the calculated anchor position
        let mealName = "\(protein.rawValue.capitalized) Tacos"
        let anchorPosition = CGPoint(x: anchorX, y: position.y)
        let meal = await model.addMeal(
            name: mealName,
            date: dinnerTime,
            mealType: .dinner,
            servings: guests,
            guests: guests,
            dinnerTime: dinnerTime,
            protein: protein,
            at: anchorPosition
        )

        // Create task nodes with linear dependency chain
        var previousTaskID: NodeID?

        for (index, scheduledTask) in scheduledTasks.enumerated() {
            // Position nodes according to their depth in the hierarchy
            // Meal is at depth 0, tasks at depth 1, 2, 3, 4, 5
            let depth = index + 1
            let taskPosition = CGPoint(
                x: anchorX + (CGFloat(depth) * actualSpacing),  // Use actual spacing (may be compressed)
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

        print("✅ TacoTemplate: Created segment config for meal \(meal.id.uuidString.prefix(8)) at anchor x=\(String(format: "%.1f", anchorX)), direction=horizontal, spacing=\(String(format: "%.1f", actualSpacing))pt (preferred=35pt), strength=0.9, nodes=6")

        // End bulk operation - this will trigger simulation with all nodes in place
        await model.endBulkOperation()

        return meal
    }
}
