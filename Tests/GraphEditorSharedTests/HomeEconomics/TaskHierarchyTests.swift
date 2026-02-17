//
//  TaskHierarchyTests.swift
//  GraphEditorSharedTests
//
//  Tests for task hierarchy and taco night workflow
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

@MainActor
struct TaskHierarchyTests {

    @Test("New task types have correct properties")
    func testNewTaskTypes() {
        // Verify assembly task types exist
        #expect(TaskType.assemble.isTopLevel == true)
        #expect(TaskType.prepMeat.isTopLevel == false)
        #expect(TaskType.assemblySetup.isTopLevel == false)

        // Verify parent relationships
        #expect(TaskType.prepMeat.parentTaskType == .prep)
        #expect(TaskType.prepVegetables.parentTaskType == .prep)
        #expect(TaskType.prepSauces.parentTaskType == .prep)
        #expect(TaskType.prepShells.parentTaskType == .prep)
        #expect(TaskType.prepToppings.parentTaskType == .prep)

        #expect(TaskType.assemblySetup.parentTaskType == .assemble)
        #expect(TaskType.assemblyBuild.parentTaskType == .assemble)
        #expect(TaskType.assemblyPlate.parentTaskType == .assemble)

        // Verify top-level tasks have no parent
        #expect(TaskType.shop.parentTaskType == nil)
        #expect(TaskType.prep.parentTaskType == nil)
        #expect(TaskType.assemble.parentTaskType == nil)
    }

    @Test("Task type display names are user-friendly")
    func testTaskTypeDisplayNames() {
        #expect(TaskType.prepMeat.displayName == "Prepare Meat")
        #expect(TaskType.prepVegetables.displayName == "Chop Vegetables")
        #expect(TaskType.assemblyBuild.displayName == "Build Tacos")
        #expect(TaskType.assemble.displayName == "Assemble & Plate")
    }

    @Test("addSubtask creates child task with hierarchy edge")
    func testAddSubtask() async throws {
        let model = GraphModel()

        // Create parent task
        let parentTask = await model.addTask(
            type: .prep,
            estimatedTime: 60,
            at: CGPoint(x: 100, y: 100)
        )

        // Add subtask
        let subtask = await model.addSubtask(
            to: parentTask.id,
            taskType: .prepMeat,
            estimatedTime: 20
        )

        #expect(subtask != nil)
        #expect(subtask?.taskType == .prepMeat)
        #expect(subtask?.estimatedTime == 20)

        // Verify hierarchy edge exists
        let hierarchyEdge = model.edges.first {
            $0.from == parentTask.id && $0.target == subtask?.id && $0.type == .hierarchy
        }
        #expect(hierarchyEdge != nil)

        // Verify parent's children array updated
        let updatedParent = model.nodes.first { $0.id == parentTask.id }?.unwrapped as? TaskNode
        #expect(updatedParent?.children.contains(subtask!.id) == true)
    }

    @Test("subtasks() retrieves all child tasks")
    func testSubtasksRetrieval() async throws {
        let model = GraphModel()

        // Create parent task
        let parentTask = await model.addTask(
            type: .prep,
            estimatedTime: 60,
            at: CGPoint(x: 100, y: 100)
        )

        // Add multiple subtasks
        let subtask1 = await model.addSubtask(to: parentTask.id, taskType: .prepMeat, estimatedTime: 20)
        let subtask2 = await model.addSubtask(to: parentTask.id, taskType: .prepVegetables, estimatedTime: 15)
        let subtask3 = await model.addSubtask(to: parentTask.id, taskType: .prepSauces, estimatedTime: 15)

        // Retrieve subtasks
        let subtasks = model.subtasks(of: parentTask.id)

        #expect(subtasks.count == 3)
        #expect(subtasks.contains { $0.id == subtask1?.id } == true)
        #expect(subtasks.contains { $0.id == subtask2?.id } == true)
        #expect(subtasks.contains { $0.id == subtask3?.id } == true)
    }

    @Test("parentTask() finds parent of subtask")
    func testParentTaskRetrieval() async throws {
        let model = GraphModel()

        // Create parent and subtask
        let parentTask = await model.addTask(
            type: .assemble,
            estimatedTime: 20,
            at: CGPoint(x: 100, y: 100)
        )

        let subtask = await model.addSubtask(
            to: parentTask.id,
            taskType: .assemblyBuild,
            estimatedTime: 10
        )

        // Find parent
        let foundParent = model.parentTask(of: subtask!.id)

        #expect(foundParent?.id == parentTask.id)
        #expect(foundParent?.taskType == .assemble)
    }

    @Test("createTacoNightTasks creates complete hierarchy")
    func testCreateTacoNightTasks() async throws {
        let model = GraphModel()

        // Create meal
        let meal = await model.addMeal(
            name: "Taco Night",
            mealType: .dinner,
            date: Date(),
            servings: 8,
            at: CGPoint(x: 0, y: 0)
        )

        // Create taco night tasks
        let tasks = await model.createTacoNightTasks(
            for: meal.id,
            guestCount: 8,
            mealPosition: meal.position
        )

        // Verify all top-level tasks created
        #expect(tasks.count >= 6) // At least 6 top-level tasks

        let taskTypes = tasks.map { $0.taskType }
        #expect(taskTypes.contains(.shop))
        #expect(taskTypes.contains(.prep))
        #expect(taskTypes.contains(.cook))
        #expect(taskTypes.contains(.assemble))
        #expect(taskTypes.contains(.serve))
        #expect(taskTypes.contains(.cleanup))

        // Verify subtasks created
        #expect(taskTypes.contains(.prepMeat))
        #expect(taskTypes.contains(.prepVegetables))
        #expect(taskTypes.contains(.prepSauces))
        #expect(taskTypes.contains(.prepToppings))
        #expect(taskTypes.contains(.prepShells))
        #expect(taskTypes.contains(.assemblySetup))
        #expect(taskTypes.contains(.assemblyBuild))
        #expect(taskTypes.contains(.assemblyPlate))

        // Verify prep task has subtasks
        let prepTask = tasks.first { $0.taskType == .prep }
        #expect(prepTask != nil)

        let prepSubtasks = model.subtasks(of: prepTask!.id)
        #expect(prepSubtasks.count == 4) // meat, veg, sauces, toppings

        // Verify assemble task has subtasks
        let assembleTask = tasks.first { $0.taskType == .assemble }
        #expect(assembleTask != nil)

        let assemblySubtasks = model.subtasks(of: assembleTask!.id)
        #expect(assemblySubtasks.count == 3) // setup, build, plate

        // Verify tasks linked to meal
        let mealTasks = model.tasks(for: meal.id)
        #expect(mealTasks.count >= 6) // Top-level tasks linked to meal
    }

    @Test("Task hierarchy positioning works correctly")
    func testTaskHierarchyPositioning() async throws {
        let model = GraphModel()

        // Create parent task at specific position
        let parentTask = await model.addTask(
            type: .prep,
            estimatedTime: 60,
            at: CGPoint(x: 100, y: 200)
        )

        // Add first subtask
        let subtask1 = await model.addSubtask(
            to: parentTask.id,
            taskType: .prepMeat,
            estimatedTime: 20
        )

        // Add second subtask
        let subtask2 = await model.addSubtask(
            to: parentTask.id,
            taskType: .prepVegetables,
            estimatedTime: 15
        )

        // Verify subtasks positioned relative to parent
        #expect(subtask1?.position.y == parentTask.position.y + 80.0)
        #expect(subtask2?.position.y == parentTask.position.y + 80.0)

        // Verify horizontal offset between subtasks
        let xDiff = abs(subtask2!.position.x - subtask1!.position.x)
        #expect(xDiff == 60.0) // Offset by 60 points
    }

    @Test("Subtask inherits assignment from parent if specified")
    func testSubtaskAssignment() async throws {
        let model = GraphModel()

        // Create a person
        let person = await model.addPerson(
            name: "Alice",
            spiceLevel: "medium",
            restrictions: [],
            at: CGPoint(x: 0, y: 0)
        )

        // Create parent task assigned to person
        let parentTask = await model.addTask(
            type: .prep,
            estimatedTime: 60,
            assignedUserID: person.id,
            at: CGPoint(x: 100, y: 100)
        )

        // Add subtask with explicit assignment
        let subtask = await model.addSubtask(
            to: parentTask.id,
            taskType: .prepMeat,
            estimatedTime: 20,
            assignedUserID: person.id
        )

        #expect(subtask?.assignedUserID == person.id)

        // Verify assignment edge exists
        let assignmentEdge = model.edges.first {
            $0.from == person.id && $0.target == subtask?.id && $0.type == .assigned
        }
        #expect(assignmentEdge != nil)
    }

    @Test("All new task types are CaseIterable")
    func testTaskTypeCaseIterable() {
        let allCases = TaskType.allCases

        // Verify all new task types in allCases
        #expect(allCases.contains(.assemble))
        #expect(allCases.contains(.prepMeat))
        #expect(allCases.contains(.prepVegetables))
        #expect(allCases.contains(.prepSauces))
        #expect(allCases.contains(.prepShells))
        #expect(allCases.contains(.prepToppings))
        #expect(allCases.contains(.assemblySetup))
        #expect(allCases.contains(.assemblyBuild))
        #expect(allCases.contains(.assemblyPlate))

        // Verify expected count (7 top-level + 8 subtasks = 15)
        #expect(allCases.count == 15)
    }

    @Test("Task nodes with children are collapsible")
    func testTaskCollapsibility() async throws {
        let model = GraphModel()

        // Create task without children
        let task1 = await model.addTask(
            type: .shop,
            estimatedTime: 45,
            at: CGPoint(x: 0, y: 0)
        )

        // Create task with children
        let task2 = await model.addTask(
            type: .prep,
            estimatedTime: 60,
            at: CGPoint(x: 100, y: 0)
        )
        await model.addSubtask(to: task2.id, taskType: .prepMeat, estimatedTime: 20)

        // Get updated task nodes
        let updatedTask1 = model.nodes.first { $0.id == task1.id }?.unwrapped as? TaskNode
        let updatedTask2 = model.nodes.first { $0.id == task2.id }?.unwrapped as? TaskNode

        // Verify collapsibility based on children
        #expect(updatedTask1?.typeDescriptor.isCollapsible == false) // No children
        #expect(updatedTask2?.typeDescriptor.isCollapsible == true)  // Has children
    }
}
