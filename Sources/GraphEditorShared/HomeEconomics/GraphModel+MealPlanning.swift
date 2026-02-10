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

    /// Calculates total work time for a meal
    @MainActor
    public func totalWorkTime(for mealID: NodeID) -> Int {
        tasks(for: mealID)
            .map { $0.actualTime ?? $0.estimatedTime }
            .reduce(0, +)
    }

    /// Generates shopping list from multiple meals
    @MainActor
    public func generateShoppingList(for mealIDs: [NodeID]) -> [String: (Decimal, MeasurementUnit)] {
        var aggregated: [String: (Decimal, MeasurementUnit)] = [:]

        for mealID in mealIDs {
            if let recipe = recipe(for: mealID) {
                for ingredient in ingredients(in: recipe.id) {
                    if let existing = aggregated[ingredient.name] {
                        // Add quantities (assuming same unit - TODO: unit conversion)
                        aggregated[ingredient.name] = (existing.0 + ingredient.quantity, ingredient.unit)
                    } else {
                        aggregated[ingredient.name] = (ingredient.quantity, ingredient.unit)
                    }
                }
            }
        }

        return aggregated
    }
}
