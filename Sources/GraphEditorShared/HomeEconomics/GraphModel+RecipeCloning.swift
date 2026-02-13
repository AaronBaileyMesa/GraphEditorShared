//
//  GraphModel+RecipeCloning.swift
//  GraphEditorShared
//
//  Recipe cloning and shopping list extensions for GraphModel
//

import Foundation
import CoreGraphics

@available(iOS 16.0, watchOS 9.0, *)
extension GraphModel {

    // MARK: - Recipe Cloning
    
    /// Clones a recipe with scaled ingredients for a specific guest count
    @MainActor
    public func cloneRecipe(
        from baseRecipeID: NodeID,
        scaledFor guestCount: Int,
        at position: CGPoint
    ) async -> RecipeNode? {
        // Get base recipe
        guard let baseRecipeNode = nodes.first(where: { $0.id == baseRecipeID }),
              let baseRecipe = baseRecipeNode.unwrapped as? RecipeNode else {
            return nil
        }
        
        // Calculate scaling factor
        let scalingFactor = Decimal(guestCount) / Decimal(baseRecipe.servings)
        
        // Create cloned recipe with scaled servings
        let clonedRecipe = await addRecipe(
            name: "\(baseRecipe.name) for \(guestCount)",
            instructions: baseRecipe.instructions,
            prepTime: baseRecipe.prepTime,
            cookTime: baseRecipe.cookTime,
            servings: guestCount,
            difficulty: baseRecipe.difficulty,
            at: position
        )
        
        // Clone and scale all ingredients
        let baseIngredients = ingredients(in: baseRecipeID)
        for ingredient in baseIngredients {
            let scaledQuantity = ingredient.quantity * scalingFactor
            
            _ = await addIngredient(
                toRecipe: clonedRecipe.id,
                name: ingredient.name,
                quantity: scaledQuantity,
                unit: ingredient.unit,
                at: CGPoint(
                    x: position.x + CGFloat.random(in: -40...40),
                    y: position.y + CGFloat.random(in: -40...40)
                )
            )
        }
        
        // Create clonedFrom edge linking back to base recipe
        await addEdge(from: clonedRecipe.id, target: baseRecipeID, type: .clonedFrom)
        
        return clonedRecipe
    }

    /// Generates shopping list from multiple meals
    @MainActor
    public func generateShoppingList(for mealIDs: [NodeID]) -> [String: (Decimal, MeasurementUnit)] {
        var aggregated: [String: (Decimal, MeasurementUnit)] = [:]

        for mealID in mealIDs {
            if let recipe = recipe(for: mealID) {
                for ingredient in ingredients(in: recipe.id) {
                    if let existing = aggregated[ingredient.name] {
                        // Add quantities (assuming same unit - FIXME: implement unit conversion)
                        aggregated[ingredient.name] = (existing.0 + ingredient.quantity, ingredient.unit)
                    } else {
                        aggregated[ingredient.name] = (ingredient.quantity, ingredient.unit)
                    }
                }
            }
        }

        return aggregated
    }
    
    // MARK: - Past Meal Recall
    
    /// Returns all MealNodes in the graph, optionally filtered by completion status
    @MainActor
    public func allMeals(completedOnly: Bool = false) -> [MealNode] {
        let meals = nodes.compactMap { $0.unwrapped as? MealNode }
        
        if completedOnly {
            return meals.filter { meal in
                isWorkflowComplete(for: meal.id)
            }
        }
        
        return meals
    }
    
    /// Returns the most recent N completed meals, sorted by date
    @MainActor
    public func recentCompletedMeals(limit: Int = 5) -> [MealNode] {
        let completed = allMeals(completedOnly: true)
        return Array(completed.sorted { $0.date > $1.date }.prefix(limit))
    }
    
    /// Returns the guest count from the most recent meal, if any
    @MainActor
    public func lastMealGuestCount() -> Int? {
        return recentCompletedMeals(limit: 1).first?.guests
    }
}
