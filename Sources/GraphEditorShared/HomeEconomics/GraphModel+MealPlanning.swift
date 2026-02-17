//
//  GraphModel+MealPlanning.swift
//  GraphEditorShared
//
//  Meal planning extensions for GraphModel
//

import Foundation
import CoreGraphics
import SwiftUI

// swiftlint:disable file_length
@available(iOS 16.0, watchOS 9.0, *)
extension GraphModel {

    // MARK: - Meal Operations

    /// Adds a meal node to the graph
    @MainActor
    public func addMeal(
        name: String,
        date: Date,
        mealType: MealType,
        servings: Int,
        recipeID: NodeID? = nil,
        at position: CGPoint
    ) async -> MealNode {
        let meal = MealNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            date: date,
            mealType: mealType,
            servings: servings,
            recipeID: recipeID
        )

        nodes.append(AnyNode(meal))
        nextNodeLabel += 1

        // Auto-create edge if recipe specified
        if let recID = recipeID {
            await addEdge(from: meal.id, target: recID, type: .requires)
        }

        return meal
    }

    /// Adds a meal node with taco dinner properties
    @MainActor
    // swiftlint:disable:next function_parameter_count
    public func addMeal(
        name: String,
        date: Date,
        mealType: MealType,
        servings: Int,
        recipeID: NodeID? = nil,
        guests: Int,
        dinnerTime: Date,
        protein: ProteinType?,
        at position: CGPoint
    ) async -> MealNode {
        let meal = MealNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            date: date,
            mealType: mealType,
            servings: servings,
            recipeID: recipeID,
            guests: guests,
            dinnerTime: dinnerTime,
            protein: protein
        )

        nodes.append(AnyNode(meal))
        nextNodeLabel += 1

        // Auto-create edge if recipe specified
        if let recID = recipeID {
            await addEdge(from: meal.id, target: recID, type: .requires)
        }

        return meal
    }

    /// Adds a recipe node
    @MainActor
    // swiftlint:disable:next function_parameter_count
    public func addRecipe(
        name: String,
        instructions: String,
        prepTime: Int,
        cookTime: Int,
        servings: Int,
        difficulty: String = "medium",
        at position: CGPoint
    ) async -> RecipeNode {
        let recipe = RecipeNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            instructions: instructions,
            prepTime: prepTime,
            cookTime: cookTime,
            servings: servings,
            difficulty: difficulty
        )

        nodes.append(AnyNode(recipe))
        nextNodeLabel += 1
        return recipe
    }

    /// Adds an ingredient to a recipe
    @MainActor
    public func addIngredient(
        toRecipe recipeID: NodeID,
        name: String,
        quantity: Decimal,
        unit: MeasurementUnit,
        at position: CGPoint
    ) async -> IngredientNode {
        let ingredient = IngredientNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            quantity: quantity,
            unit: unit
        )

        nodes.append(AnyNode(ingredient))
        nextNodeLabel += 1

        // Auto-create contains edge
        await addEdge(from: recipeID, target: ingredient.id, type: .contains)

        return ingredient
    }

    /// Adds a task node
    @MainActor
    public func addTask(
        type: TaskType,
        estimatedTime: Int,
        assignedUserID: NodeID? = nil,
        at position: CGPoint
    ) async -> TaskNode {
        let task = TaskNode(
            label: nextNodeLabel,
            position: position,
            taskType: type,
            status: .pending,
            estimatedTime: estimatedTime,
            actualTime: nil,
            assignedUserID: assignedUserID
        )

        nodes.append(AnyNode(task))
        nextNodeLabel += 1

        // Auto-create assignment edge if user specified
        if let userID = assignedUserID {
            await addEdge(from: userID, target: task.id, type: .assigned)
        }

        return task
    }

    /// Adds a task node with planned timestamps
    @MainActor
    public func addTask(
        type: TaskType,
        estimatedTime: Int,
        assignedUserID: NodeID? = nil,
        plannedStart: Date?,
        plannedEnd: Date?,
        at position: CGPoint
    ) async -> TaskNode {
        let task = TaskNode(
            label: nextNodeLabel,
            position: position,
            taskType: type,
            status: .pending,
            estimatedTime: estimatedTime,
            actualTime: nil,
            assignedUserID: assignedUserID,
            plannedStart: plannedStart,
            plannedEnd: plannedEnd
        )

        nodes.append(AnyNode(task))
        nextNodeLabel += 1

        // Auto-create assignment edge if user specified
        if let userID = assignedUserID {
            await addEdge(from: userID, target: task.id, type: .assigned)
        }

        return task
    }

    /// Update task status and handle timestamp recording
    @MainActor
    public func updateTaskStatus(_ taskID: NodeID, to newStatus: TaskStatus) {
        guard let index = nodes.firstIndex(where: { $0.id == taskID }),
              let taskNode = nodes[index].unwrapped as? TaskNode else {
            return
        }

        let updatedTask: TaskNode
        switch newStatus {
        case .inProgress:
            updatedTask = taskNode.startingWork()
        case .completed:
            // Use existing actualTime or estimated time
            let timeSpent = taskNode.actualTime ?? taskNode.estimatedTime
            updatedTask = taskNode.completing(timeSpent: timeSpent)
        case .blocked:
            updatedTask = taskNode.blocking()
        case .declined:
            updatedTask = taskNode.declining()
        case .skipped:
            updatedTask = taskNode.skipping()
        case .pending:
            var updated = taskNode
            updated.status = .pending
            updatedTask = updated
        }

        nodes[index] = AnyNode(updatedTask)
    }

    // MARK: - Query Helpers

    /// Returns all ingredients in a recipe
    @MainActor
    public func ingredients(in recipeID: NodeID) -> [IngredientNode] {
        edges
            .filter { $0.from == recipeID && $0.type == .contains }
            .compactMap { edge in
                nodes.first(where: { $0.id == edge.target })?.unwrapped as? IngredientNode
            }
    }

    /// Returns the recipe for a meal
    @MainActor
    public func recipe(for mealID: NodeID) -> RecipeNode? {
        edges
            .filter { $0.from == mealID && $0.type == .requires }
            .compactMap { edge in
                nodes.first(where: { $0.id == edge.target })?.unwrapped as? RecipeNode
            }
            .first
    }
    
    /// Returns the preference node that configures a meal
    @MainActor
    public func preference(for mealID: NodeID) -> PreferenceNode? {
        edges
            .filter { $0.target == mealID && $0.type == .configures }
            .compactMap { edge in
                nodes.first(where: { $0.id == edge.from })?.unwrapped as? PreferenceNode
            }
            .first
    }

    /// Returns all tasks assigned to a user
    @MainActor
    public func tasks(assignedTo userID: NodeID) -> [TaskNode] {
        edges
            .filter { $0.from == userID && $0.type == .assigned }
            .compactMap { edge in
                nodes.first(where: { $0.id == edge.target })?.unwrapped as? TaskNode
            }
    }

    /// Returns tasks for a specific meal (via hierarchy edges)
    @MainActor
    public func tasks(for mealID: NodeID) -> [TaskNode] {
        edges
            .filter { $0.from == mealID && $0.type == .hierarchy }
            .compactMap { edge in
                nodes.first(where: { $0.id == edge.target })?.unwrapped as? TaskNode
            }
    }
    
    /// Adds a task to a meal with automatic positioning and hierarchy edge
    @MainActor
    public func addTaskToMeal(mealID: NodeID, taskType: TaskType, estimatedTime: Int = 30) async {
        guard let mealIndex = nodes.firstIndex(where: { $0.id == mealID }) else { return }
        let meal = nodes[mealIndex].unwrapped
        
        // Find last task in chain to append after it
        let existingTasks = orderedTasks(for: mealID)
        let parentID: NodeID
        let parentPos: CGPoint
        
        if let lastTask = existingTasks.last {
            parentID = lastTask.id
            parentPos = lastTask.position
        } else {
            parentID = mealID
            parentPos = meal.position
        }
        
        // Position new task offset from parent
        let angle = CGFloat.random(in: 0 ..< .pi * 2)
        let dist: CGFloat = 80
        let taskPos = parentPos + CGPoint(x: dist * cos(angle), y: dist * sin(angle))
        
        let task = await addTask(
            type: taskType,
            estimatedTime: estimatedTime,
            at: taskPos
        )
        
        // Create hierarchy edge from parent (meal or last task)
        await addEdge(from: parentID, target: task.id, type: .hierarchy)
    }

    /// Calculates total work time for a meal
    @MainActor
    public func totalWorkTime(for mealID: NodeID) -> Int {
        tasks(for: mealID)
            .map { $0.actualTime ?? $0.estimatedTime }
            .reduce(0, +)
    }
    
    // MARK: - Table Seating Management
    
    /// Gets or creates table seating for a meal
    @MainActor
    public func tableSeating(for mealID: NodeID) -> TableSeating {
        if let existing = tableSeatingsByMeal[mealID] {
            return existing
        }
        
        // Create new seating arrangement
        let seating = TableSeating(mealID: mealID)
        tableSeatingsByMeal[mealID] = seating
        return seating
    }
    
    /// Updates table seating for a meal
    @MainActor
    public func updateTableSeating(_ seating: TableSeating) async {
        tableSeatingsByMeal[seating.mealID] = seating
        try? await saveGraph()
    }
    
    /// Assigns a person to a seat at a meal's table
    @MainActor
    public func assignSeat(personID: NodeID, to seatIndex: Int, for mealID: NodeID) async {
        var seating = tableSeating(for: mealID)
        
        // Remove person from any previous seat
        seating.remove(personID: personID)
        
        // Assign to new seat
        seating.assign(personID: personID, to: seatIndex)
        
        await updateTableSeating(seating)
    }
    
    /// Removes a person from their seat at a meal's table
    @MainActor
    public func removeSeat(personID: NodeID, for mealID: NodeID) async {
        var seating = tableSeating(for: mealID)
        seating.remove(personID: personID)
        await updateTableSeating(seating)
    }
    
    /// Gets all person nodes assigned to seats for a meal
    @MainActor
    public func seatedPersons(for mealID: NodeID) -> [(PersonNode, Int)] {
        let seating = tableSeating(for: mealID)
        return seating.assignments.compactMap { (seatIndex, personID) in
            guard let personNode = nodes.first(where: { $0.id == personID }),
                  let person = personNode.unwrapped as? PersonNode else {
                return nil
            }
            return (person, seatIndex)
        }
    }
    
    /// Gets all person nodes that could be seated (not yet assigned)
    @MainActor
    public func unseatedPersons(for mealID: NodeID) -> [PersonNode] {
        let seating = tableSeating(for: mealID)
        let assignedIDs = Set(seating.assignments.values)

        return nodes.compactMap { node in
            guard let person = node.unwrapped as? PersonNode,
                  !assignedIDs.contains(person.id) else {
                return nil
            }
            return person
        }
    }

    // MARK: - Meal-Table Linking

    /// Links a meal to its table
    @MainActor
    public func linkMealToTable(mealID: NodeID, tableID: NodeID) async {
        await addEdge(from: mealID, target: tableID, type: .association)
    }

    /// Gets the table linked to a meal
    @MainActor
    public func table(for mealID: NodeID) -> TableNode? {
        guard let tableEdge = edges.first(where: {
            $0.from == mealID && $0.type == .association
        }),
        let tableNode = nodes.first(where: { $0.id == tableEdge.target }) else {
            return nil
        }

        return tableNode.unwrapped as? TableNode
    }

    // MARK: - Person-Table Lookup Cache (Performance Optimization)

    /// Rebuilds the person-to-table cache by scanning all tables
    @MainActor
    public func rebuildPersonToTableCache() {
        personToTableCache.removeAll()
        for node in nodes {
            if let table = node.unwrapped as? TableNode {
                for personID in table.seatingAssignments.values {
                    personToTableCache[personID] = table.id
                }
            }
        }
    }
    
    /// Migrates all seated persons to their correct positions
    /// Call this after loading a graph to update person positions to match current seat calculations
    @MainActor
    public func migrateSeatedPersonPositions() {
        var updated = false

        #if DEBUG
        print("🔄 Starting seated person migration...")
        #endif

        for tableNode in nodes {
            guard let table = tableNode.unwrapped as? TableNode else { continue }

            #if DEBUG
            print("🔄 Checking table '\(table.name)' with \(table.seatingAssignments.count) seated persons")
            #endif

            // Update each person seated at this table
            for (seatIndex, personID) in table.seatingAssignments {
                guard let personIndex = nodes.firstIndex(where: { $0.id == personID }),
                      var person = nodes[personIndex].unwrapped as? PersonNode else {
                    continue
                }
                
                // Calculate correct seat position
                let correctPosition = table.seatPosition(for: seatIndex)
                
                // Check if person needs repositioning (tolerance of 0.1pt)
                // swiftlint:disable:next identifier_name
                let dx = person.position.x - correctPosition.x
                // swiftlint:disable:next identifier_name
                let dy = person.position.y - correctPosition.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance > 0.1 {
                    // Update person position
                    person = person.with(position: correctPosition, velocity: .zero)
                    nodes[personIndex] = AnyNode(person)
                    updated = true
                    
                    #if DEBUG
                    print("🔄 Migrated person \(person.name) to seat \(seatIndex) (moved \(String(format: "%.1f", distance))pt)")
                    #endif
                }
            }
        }
        
        if updated {
            #if DEBUG
            print("✅ Seated person migration complete")
            #endif
        }
    }

    /// Fast O(1) lookup of table position for a seated person
    @MainActor
    public func tablePosition(for personID: NodeID) -> CGPoint? {
        guard let tableID = personToTableCache[personID],
              let table = nodes.first(where: { $0.id == tableID })?.unwrapped as? TableNode else {
            return nil
        }
        return table.position
    }

    /// Updates cache when person is assigned to table
    @MainActor
    func updateCacheForAssignment(personID: NodeID, tableID: NodeID) {
        personToTableCache[personID] = tableID
    }

    /// Updates cache when person is removed from table
    @MainActor
    func updateCacheForRemoval(personID: NodeID) {
        personToTableCache.removeValue(forKey: personID)
    }

    // MARK: - Task Hierarchy Methods

    /// Adds a subtask to a parent task
    @MainActor
    public func addSubtask(
        to parentTaskID: NodeID,
        taskType: TaskType,
        estimatedTime: Int,
        assignedUserID: NodeID? = nil
    ) async -> TaskNode? {
        guard let parentIndex = nodes.firstIndex(where: { $0.id == parentTaskID }),
              var parentTask = nodes[parentIndex].unwrapped as? TaskNode else {
            return nil
        }

        // Position subtask near parent
        let offset = CGFloat(parentTask.children.count) * 60.0
        let subtaskPosition = CGPoint(
            x: parentTask.position.x + offset,
            y: parentTask.position.y + 80.0
        )

        // Create subtask
        let subtask = await addTask(
            type: taskType,
            estimatedTime: estimatedTime,
            assignedUserID: assignedUserID,
            at: subtaskPosition
        )

        // Update parent's children array
        parentTask = parentTask.with(children: parentTask.children + [subtask.id])
        parentTask = parentTask.with(childOrder: parentTask.childOrder + [subtask.id])
        nodes[parentIndex] = AnyNode(parentTask)

        // Create hierarchy edge
        await addEdge(from: parentTaskID, target: subtask.id, type: .hierarchy)

        try? await saveGraph()
        return subtask
    }

    /// Gets all subtasks of a parent task
    @MainActor
    public func subtasks(of parentTaskID: NodeID) -> [TaskNode] {
        guard let parentNode = nodes.first(where: { $0.id == parentTaskID }),
              let parent = parentNode.unwrapped as? TaskNode else {
            return []
        }

        return parent.children.compactMap { childID in
            nodes.first(where: { $0.id == childID })?.unwrapped as? TaskNode
        }
    }

    /// Gets the parent task of a subtask (if any)
    @MainActor
    public func parentTask(of subtaskID: NodeID) -> TaskNode? {
        // Find hierarchy edge pointing to this subtask
        guard let hierarchyEdge = edges.first(where: {
            $0.type == .hierarchy && $0.target == subtaskID
        }) else {
            return nil
        }

        return nodes.first(where: { $0.id == hierarchyEdge.from })?.unwrapped as? TaskNode
    }

    /// Creates detailed taco night task hierarchy.
    /// Top-level tasks are chained sequentially (meal→shop→prep→cook→assemble→serve→cleanup)
    /// so that orderedTasks(for:) returns them in workflow order.
    /// Subtasks are children of their parent task via hierarchy edges.
    @MainActor
    public func createTacoNightTasks(
        for mealID: NodeID,
        guestCount: Int,
        mealPosition: CGPoint
    ) async -> [TaskNode] {
        var createdTasks: [TaskNode] = []

        // Calculate task positions in a vertical column below meal
        let baseX = mealPosition.x
        var currentY = mealPosition.y + 100.0

        // 1. Shop task — linked from meal
        let shopTask = await addTask(
            type: .shop,
            estimatedTime: 45,
            at: CGPoint(x: baseX, y: currentY)
        )
        createdTasks.append(shopTask)
        await addEdge(from: mealID, target: shopTask.id, type: .hierarchy)
        currentY += 60

        // 2. Prep task (with subtasks) — linked from shop
        let prepTask = await addTask(
            type: .prep,
            estimatedTime: 60,
            at: CGPoint(x: baseX, y: currentY)
        )
        createdTasks.append(prepTask)
        await addEdge(from: shopTask.id, target: prepTask.id, type: .hierarchy)
        currentY += 60

        // Prep subtasks
        if let meatSubtask = await addSubtask(to: prepTask.id, taskType: .prepMeat, estimatedTime: 20) {
            createdTasks.append(meatSubtask)
        }
        if let vegSubtask = await addSubtask(to: prepTask.id, taskType: .prepVegetables, estimatedTime: 15) {
            createdTasks.append(vegSubtask)
        }
        if let sauceSubtask = await addSubtask(to: prepTask.id, taskType: .prepSauces, estimatedTime: 15) {
            createdTasks.append(sauceSubtask)
        }
        if let toppingSubtask = await addSubtask(to: prepTask.id, taskType: .prepToppings, estimatedTime: 10) {
            createdTasks.append(toppingSubtask)
        }

        // 3. Cook task — linked from prep
        let cookTask = await addTask(
            type: .cook,
            estimatedTime: 25,
            at: CGPoint(x: baseX, y: currentY)
        )
        createdTasks.append(cookTask)
        await addEdge(from: prepTask.id, target: cookTask.id, type: .hierarchy)
        currentY += 60

        if let shellSubtask = await addSubtask(to: cookTask.id, taskType: .prepShells, estimatedTime: 5) {
            createdTasks.append(shellSubtask)
        }

        // 4. Assemble task (with subtasks) — linked from cook
        let assembleTask = await addTask(
            type: .assemble,
            estimatedTime: 20,
            at: CGPoint(x: baseX, y: currentY)
        )
        createdTasks.append(assembleTask)
        await addEdge(from: cookTask.id, target: assembleTask.id, type: .hierarchy)
        currentY += 60

        // Assembly subtasks
        if let setupSubtask = await addSubtask(to: assembleTask.id, taskType: .assemblySetup, estimatedTime: 5) {
            createdTasks.append(setupSubtask)
        }
        if let buildSubtask = await addSubtask(to: assembleTask.id, taskType: .assemblyBuild, estimatedTime: 10) {
            createdTasks.append(buildSubtask)
        }
        if let plateSubtask = await addSubtask(to: assembleTask.id, taskType: .assemblyPlate, estimatedTime: 5) {
            createdTasks.append(plateSubtask)
        }

        // 5. Serve task — linked from assemble
        let serveTask = await addTask(
            type: .serve,
            estimatedTime: 5,
            at: CGPoint(x: baseX, y: currentY)
        )
        createdTasks.append(serveTask)
        await addEdge(from: assembleTask.id, target: serveTask.id, type: .hierarchy)
        currentY += 60

        // 6. Cleanup task — linked from serve
        let cleanupTask = await addTask(
            type: .cleanup,
            estimatedTime: 30,
            at: CGPoint(x: baseX, y: currentY)
        )
        createdTasks.append(cleanupTask)
        await addEdge(from: serveTask.id, target: cleanupTask.id, type: .hierarchy)

        try? await saveGraph()
        return createdTasks
    }

    /// Helper to link a task to a meal via hierarchy edge
    @MainActor
    private func addTaskToMeal(mealID: NodeID, taskID: NodeID) async {
        await addEdge(from: mealID, target: taskID, type: .hierarchy)
    }
}
