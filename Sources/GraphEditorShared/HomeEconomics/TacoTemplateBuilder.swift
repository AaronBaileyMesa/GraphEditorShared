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

    // MARK: - Supporting Types

    /// Definition of a task without scheduling
    public struct TaskDefinition {
        public let type: TaskType
        public let minutes: Int
        public let label: String

        public init(type: TaskType, minutes: Int, label: String) {
            self.type = type
            self.minutes = minutes
            self.label = label
        }
    }

    /// A task with scheduled start and end times
    public struct ScheduledTask {
        public let type: TaskType
        public let minutes: Int
        public let label: String
        public let plannedStart: Date
        public let plannedEnd: Date

        public init(type: TaskType, minutes: Int, label: String, plannedStart: Date, plannedEnd: Date) {
            self.type = type
            self.minutes = minutes
            self.label = label
            self.plannedStart = plannedStart
            self.plannedEnd = plannedEnd
        }
    }

    // MARK: - Task Definitions (v1)

    /// Phase 2C v1 tasks: complete workflow ending with "Serve"
    public static let v1Tasks: [TaskDefinition] = [
        TaskDefinition(type: .plan, minutes: 5, label: "Check Pantry"),
        TaskDefinition(type: .shop, minutes: 45, label: "Shop"),
        TaskDefinition(type: .prep, minutes: 20, label: "Prep"),
        TaskDefinition(type: .cook, minutes: 25, label: "Cook"),
        TaskDefinition(type: .serve, minutes: 5, label: "Serve")
    ]

    // MARK: - Schedule Calculation

    /// Calculate planned start and end times for each task, working backward from dinner time
    public static func calculateSchedule(
        dinnerTime: Date,
        tasks: [TaskDefinition]
    ) -> [ScheduledTask] {
        var result: [ScheduledTask] = []
        var currentEndTime = dinnerTime

        // Work backward from dinner time
        for task in tasks.reversed() {
            let plannedEnd = currentEndTime
            let plannedStart = Calendar.current.date(byAdding: .minute, value: -task.minutes, to: plannedEnd)!

            result.insert(
                ScheduledTask(
                    type: task.type,
                    minutes: task.minutes,
                    label: task.label,
                    plannedStart: plannedStart,
                    plannedEnd: plannedEnd
                ),
                at: 0
            )

            currentEndTime = plannedStart
        }

        return result
    }

    // MARK: - Graph Building

    /// Build a complete taco dinner graph with meal node and task nodes
    @MainActor
    // swiftlint:disable:next function_body_length
    public static func buildGraph(
        in model: GraphModel,
        guests: Int,
        dinnerTime: Date,
        protein: ProteinType,
        at position: CGPoint
    ) async -> MealNode {
        // Begin bulk operation to prevent simulation from running during construction
        await model.beginBulkOperation()

        // Create meal node at the specified position
        let mealName = "\(protein.rawValue.capitalized) Tacos"
        let anchorPosition = position
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

        // Create detailed task hierarchy with assembly subtasks
        let tasks = await model.createTacoNightTasks(
            for: meal.id,
            guestCount: guests,
            mealPosition: anchorPosition
        )
        
        print("✅ TacoTemplate: Created \(tasks.count) tasks with detailed assembly workflow")
        
        // Configure directional layout for this segment (default: horizontal)
        // Optimized for watchOS: very strong forces to overcome node repulsion
        model.setSegmentConfig(
            rootNodeID: meal.id,
            direction: .horizontal,
            strength: 1.5,           // Very strong forces to overcome repulsion (1.5 → 1.2 effective)
            nodeSpacing: 35.0        // Tight spacing for watch screen (~205pt wide)
        )

        print("✅ TacoTemplate: Created segment config for meal \(meal.id.uuidString.prefix(8)), direction=horizontal, strength=1.5, tasks=\(tasks.count)")

        // End bulk operation - this will trigger simulation with all nodes in place
        await model.endBulkOperation()

        return meal
    }
    
    // MARK: - Decision Tree Builder

    // swiftlint:disable function_body_length
    /// Builds a sample taco night decision tree for testing
    @MainActor
    public static func buildDecisionTree(
        in model: GraphModel,
        at startPosition: CGPoint = CGPoint(x: 50, y: 125)
    ) async -> DecisionNode {
        // Begin bulk operation to prevent simulation from running during construction
        await model.beginBulkOperation()
        
        // Better spacing for watch screen (205pt wide, 251pt tall)
        // Decisions in a horizontal line with choices below
        let horizontalSpacing: CGFloat = 50  // Space between decision nodes
        let choiceOffset: CGFloat = 35       // Vertical offset for first choice
        let choiceSpacing: CGFloat = 20      // Space between choices
        
        // Decision 1: How many guests? (centered in view)
        let guestDecision = await model.addDecision(
            question: "How many guests?",
            preferenceKey: "guestCount",
            inputType: .numeric,
            at: startPosition
        )
        
        // Decision 2: What protein?
        let proteinDecision = await model.addDecision(
            question: "What protein?",
            preferenceKey: "protein",
            inputType: .singleChoice,
            at: CGPoint(x: startPosition.x + horizontalSpacing, y: startPosition.y)
        )
        
        _ = await model.addChoice(
            to: proteinDecision.id,
            choiceText: "Beef",
            value: .string("beef"),
            at: CGPoint(x: startPosition.x + horizontalSpacing, y: startPosition.y + choiceOffset)
        )
        
        _ = await model.addChoice(
            to: proteinDecision.id,
            choiceText: "Chicken",
            value: .string("chicken"),
            at: CGPoint(x: startPosition.x + horizontalSpacing, y: startPosition.y + choiceOffset + choiceSpacing)
        )
        
        _ = await model.addChoice(
            to: proteinDecision.id,
            choiceText: "Fish",
            value: .string("fish"),
            at: CGPoint(x: startPosition.x + horizontalSpacing, y: startPosition.y + choiceOffset + choiceSpacing * 2)
        )
        
        // Decision 3: Spice level?
        let spiceDecision = await model.addDecision(
            question: "Spice level?",
            preferenceKey: "spiceLevel",
            inputType: .singleChoice,
            at: CGPoint(x: startPosition.x + horizontalSpacing * 2, y: startPosition.y)
        )
        
        _ = await model.addChoice(
            to: spiceDecision.id,
            choiceText: "Mild",
            value: .string("mild"),
            at: CGPoint(x: startPosition.x + horizontalSpacing * 2, y: startPosition.y + choiceOffset)
        )
        
        _ = await model.addChoice(
            to: spiceDecision.id,
            choiceText: "Medium",
            value: .string("medium"),
            at: CGPoint(x: startPosition.x + horizontalSpacing * 2, y: startPosition.y + choiceOffset + choiceSpacing)
        )
        
        _ = await model.addChoice(
            to: spiceDecision.id,
            choiceText: "Hot",
            value: .string("hot"),
            at: CGPoint(x: startPosition.x + horizontalSpacing * 2, y: startPosition.y + choiceOffset + choiceSpacing * 2)
        )
        
        // Decision 4: Toppings? (multi-choice)
        let toppingsDecision = await model.addDecision(
            question: "What toppings?",
            preferenceKey: "toppings",
            inputType: .multiChoice,
            at: CGPoint(x: startPosition.x + horizontalSpacing * 3, y: startPosition.y)
        )
        
        _ = await model.addChoice(
            to: toppingsDecision.id,
            choiceText: "Lettuce",
            value: .string("lettuce"),
            at: CGPoint(x: startPosition.x + horizontalSpacing * 3, y: startPosition.y + choiceOffset)
        )
        
        _ = await model.addChoice(
            to: toppingsDecision.id,
            choiceText: "Tomato",
            value: .string("tomato"),
            at: CGPoint(x: startPosition.x + horizontalSpacing * 3, y: startPosition.y + choiceOffset + choiceSpacing)
        )
        
        _ = await model.addChoice(
            to: toppingsDecision.id,
            choiceText: "Cheese",
            value: .string("cheese"),
            at: CGPoint(x: startPosition.x + horizontalSpacing * 3, y: startPosition.y + choiceOffset + choiceSpacing * 2)
        )
        
        _ = await model.addChoice(
            to: toppingsDecision.id,
            choiceText: "Sour Cream",
            value: .string("sourCream"),
            at: CGPoint(x: startPosition.x + horizontalSpacing * 3, y: startPosition.y + choiceOffset + choiceSpacing * 3)
        )
        
        // Link decisions in sequence
        await model.linkDecisions(from: guestDecision.id, to: proteinDecision.id)
        await model.linkDecisions(from: proteinDecision.id, to: spiceDecision.id)
        await model.linkDecisions(from: spiceDecision.id, to: toppingsDecision.id)
        
        // Verify edges were created
        let precedesEdges = model.edges.filter { $0.type == .precedes }
        print("🔗 Decision Tree: Created \(precedesEdges.count) precedes edges")
        for edge in precedesEdges {
            print("  Edge: \(edge.from.uuidString.prefix(8)) -> \(edge.target.uuidString.prefix(8))")
        }
        
        // Configure directional layout for decision tree (horizontal flow)
        // Use high strength (15.0) to overcome repulsion forces and prevent oscillation
        model.setSegmentConfig(
            rootNodeID: guestDecision.id,
            direction: .horizontal,
            strength: 15.0,
            nodeSpacing: horizontalSpacing
        )
        
        print("✅ Decision Tree: Created 4 decisions with choices at center position")
        print("📐 Segment config set for decision tree: root=\(guestDecision.id.uuidString.prefix(8)), direction=horizontal, spacing=\(horizontalSpacing)")
        print("📊 Segment configs in model: \(model.segmentConfigs.count) total")
        print("🎯 Decision node IDs:")
        print("  Guest: \(guestDecision.id.uuidString.prefix(8))")
        print("  Protein: \(proteinDecision.id.uuidString.prefix(8))")
        print("  Spice: \(spiceDecision.id.uuidString.prefix(8))")
        print("  Toppings: \(toppingsDecision.id.uuidString.prefix(8))")
        
        // End bulk operation - this will trigger simulation with all nodes in place
        await model.endBulkOperation()

        return guestDecision
    }
    // swiftlint:enable function_body_length
}
