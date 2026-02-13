//
//  GraphModel+MealPlanning.swift
//  GraphEditorShared
//
//  Meal planning extensions for GraphModel
//

import Foundation
import CoreGraphics
import SwiftUI

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
    public func assignSeat(personID: NodeID, to position: SeatPosition, for mealID: NodeID) async {
        var seating = tableSeating(for: mealID)
        
        // Remove person from any previous seat
        seating.remove(personID: personID)
        
        // Assign to new seat
        seating.assign(personID: personID, to: position)
        
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
    public func seatedPersons(for mealID: NodeID) -> [(PersonNode, SeatPosition)] {
        let seating = tableSeating(for: mealID)
        return seating.assignments.compactMap { (position, personID) in
            guard let personNode = nodes.first(where: { $0.id == personID }),
                  let person = personNode.unwrapped as? PersonNode else {
                return nil
            }
            return (person, position)
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

    // MARK: - Table Node Management

    /// Adds a table node to the graph
    @MainActor
    public func addTable(
        name: String,
        headSeats: Int = 1,
        sideSeats: Int = 3,
        tableLength: CGFloat = 50.0,
        tableWidth: CGFloat = 30.0,
        at position: CGPoint
    ) async -> TableNode {
        let table = TableNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            headSeats: headSeats,
            sideSeats: sideSeats,
            tableLength: tableLength,
            tableWidth: tableWidth
        )

        nodes.append(AnyNode(table))
        nextNodeLabel += 1
        return table
    }

    /// Assigns a person to a seat at a table and positions the person node
    @MainActor
    public func assignPersonToTable(
        personID: NodeID,
        tableID: NodeID,
        seatPosition: SeatPosition
    ) async {
        // Get the table and person nodes
        guard let tableIndex = nodes.firstIndex(where: { $0.id == tableID }),
              var table = nodes[tableIndex].unwrapped as? TableNode,
              let personIndex = nodes.firstIndex(where: { $0.id == personID }),
              var person = nodes[personIndex].unwrapped as? PersonNode else {
            return
        }

        // Remove person from any previous seat
        table.seatingAssignments = table.seatingAssignments.filter { $0.value != personID }

        // Assign to new seat
        table.seatingAssignments[seatPosition] = personID

        // Calculate and set person's position
        let newPosition = table.seatPosition(for: seatPosition)
        person = person.with(position: newPosition, velocity: .zero)

        // Update both nodes
        nodes[tableIndex] = AnyNode(table)
        nodes[personIndex] = AnyNode(person)

        // Create association edge from table to person
        await addEdge(from: tableID, target: personID, type: .association)

        // Update cache
        updateCacheForAssignment(personID: personID, tableID: tableID)

        try? await saveGraph()
    }

    /// Removes a person from a table
    @MainActor
    public func removePersonFromTable(
        personID: NodeID,
        tableID: NodeID
    ) async {
        guard let tableIndex = nodes.firstIndex(where: { $0.id == tableID }),
              var table = nodes[tableIndex].unwrapped as? TableNode else {
            return
        }

        // Remove from seating assignments
        table.seatingAssignments = table.seatingAssignments.filter { $0.value != personID }
        nodes[tableIndex] = AnyNode(table)

        // Remove edge
        edges.removeAll { $0.from == tableID && $0.target == personID }

        // Update cache
        updateCacheForRemoval(personID: personID)

        try? await saveGraph()
    }

    /// Arranges all assigned persons around a table
    @MainActor
    public func arrangePersonsAroundTable(tableID: NodeID) {
        guard let tableIndex = nodes.firstIndex(where: { $0.id == tableID }),
              let table = nodes[tableIndex].unwrapped as? TableNode else {
            return
        }

        // Position each assigned person
        for (seatPosition, personID) in table.seatingAssignments {
            if let personIndex = nodes.firstIndex(where: { $0.id == personID }),
               var person = nodes[personIndex].unwrapped as? PersonNode {
                let newPosition = table.seatPosition(for: seatPosition)
                person = person.with(position: newPosition, velocity: .zero)
                nodes[personIndex] = AnyNode(person)
            }
        }
    }

    /// Updates a table's position and automatically repositions seated persons
    @MainActor
    public func updateTablePosition(tableID: NodeID, to position: CGPoint) {
        guard let tableIndex = nodes.firstIndex(where: { $0.id == tableID }),
              var table = nodes[tableIndex].unwrapped as? TableNode else {
            return
        }

        // Update table position
        table = table.with(position: position, velocity: .zero)
        nodes[tableIndex] = AnyNode(table)

        // Automatically rearrange seated persons
        arrangePersonsAroundTable(tableID: tableID)
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
        
        for (tableIndex, tableNode) in nodes.enumerated() {
            guard let table = tableNode.unwrapped as? TableNode else { continue }
            
            // Update each person seated at this table
            for (seatPosition, personID) in table.seatingAssignments {
                guard let personIndex = nodes.firstIndex(where: { $0.id == personID }),
                      var person = nodes[personIndex].unwrapped as? PersonNode else {
                    continue
                }
                
                // Calculate correct seat position
                let correctPosition = table.seatPosition(for: seatPosition)
                
                // Check if person needs repositioning (tolerance of 0.1pt)
                let dx = person.position.x - correctPosition.x
                let dy = person.position.y - correctPosition.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance > 0.1 {
                    // Update person position
                    person = person.with(position: correctPosition, velocity: .zero)
                    nodes[personIndex] = AnyNode(person)
                    updated = true
                    
                    #if DEBUG
                    print("🔄 Migrated person \(person.name) to seat \(seatPosition.rawValue) (moved \(String(format: "%.1f", distance))pt)")
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
    private func updateCacheForAssignment(personID: NodeID, tableID: NodeID) {
        personToTableCache[personID] = tableID
    }

    /// Updates cache when person is removed from table
    @MainActor
    private func updateCacheForRemoval(personID: NodeID) {
        personToTableCache.removeValue(forKey: personID)
    }
}
