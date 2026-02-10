//
//  GraphModelMealPlanningTests.swift
//  GraphEditorSharedTests
//
//  Tests for GraphModel meal planning extensions
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

@available(iOS 16.0, watchOS 9.0, *)
struct GraphModelMealPlanningTests {

    @MainActor
    private func setupModel() -> GraphModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        return GraphModel(storage: storage, physicsEngine: physicsEngine)
    }

    @Test("Add meal creates node with correct properties")
    @MainActor
    func testAddMeal() async {
        let model = setupModel()
        let date = Date()

        let meal = await model.addMeal(
            name: "Monday Dinner",
            date: date,
            mealType: .dinner,
            servings: 4,
            at: .zero
        )

        #expect(meal.name == "Monday Dinner")
        #expect(meal.date == date)
        #expect(meal.mealType == .dinner)
        #expect(meal.servings == 4)
        #expect(model.nodes.count == 1)
    }

    @Test("Add meal with recipeID creates requires edge")
    @MainActor
    func testAddMealWithRecipe() async {
        let model = setupModel()

        let recipe = await model.addRecipe(
            name: "Pasta",
            instructions: "Cook pasta",
            prepTime: 5,
            cookTime: 10,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )

        let meal = await model.addMeal(
            name: "Dinner",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            recipeID: recipe.id,
            at: .zero
        )

        #expect(model.nodes.count == 2)
        #expect(model.edges.count == 1)

        let edge = model.edges.first!
        #expect(edge.from == meal.id)
        #expect(edge.target == recipe.id)
        #expect(edge.type == .requires)
    }

    @Test("Add recipe creates node")
    @MainActor
    func testAddRecipe() async {
        let model = setupModel()

        let recipe = await model.addRecipe(
            name: "Spaghetti Carbonara",
            instructions: "1. Boil pasta...",
            prepTime: 10,
            cookTime: 15,
            servings: 4,
            difficulty: "medium",
            at: .zero
        )

        #expect(recipe.name == "Spaghetti Carbonara")
        #expect(recipe.prepTime == 10)
        #expect(recipe.cookTime == 15)
        #expect(model.nodes.count == 1)
    }

    @Test("Add ingredient creates node and contains edge")
    @MainActor
    func testAddIngredient() async {
        let model = setupModel()

        let recipe = await model.addRecipe(
            name: "Soup",
            instructions: "Boil",
            prepTime: 5,
            cookTime: 20,
            servings: 4,
            at: .zero
        )

        let ingredient = await model.addIngredient(
            toRecipe: recipe.id,
            name: "Carrots",
            quantity: 2,
            unit: .cup,
            at: CGPoint(x: 50, y: 50)
        )

        #expect(ingredient.name == "Carrots")
        #expect(ingredient.quantity == 2)
        #expect(ingredient.unit == .cup)
        #expect(model.nodes.count == 2)
        #expect(model.edges.count == 1)

        let edge = model.edges.first!
        #expect(edge.from == recipe.id)
        #expect(edge.target == ingredient.id)
        #expect(edge.type == .contains)
    }

    @Test("Add task creates node")
    @MainActor
    func testAddTask() async {
        let model = setupModel()

        let task = await model.addTask(
            type: .shop,
            estimatedTime: 30,
            at: .zero
        )

        #expect(task.taskType == .shop)
        #expect(task.status == .pending)
        #expect(task.estimatedTime == 30)
        #expect(model.nodes.count == 1)
    }

    @Test("Add task with userID creates assigned edge")
    @MainActor
    func testAddTaskWithUser() async {
        let model = setupModel()
        let userID = UUID()

        let task = await model.addTask(
            type: .cook,
            estimatedTime: 45,
            assignedUserID: userID,
            at: .zero
        )

        #expect(model.edges.count == 1)

        let edge = model.edges.first!
        #expect(edge.from == userID)
        #expect(edge.target == task.id)
        #expect(edge.type == .assigned)
    }

    @Test("Query ingredients in recipe")
    @MainActor
    func testIngredientsQuery() async {
        let model = setupModel()

        let recipe = await model.addRecipe(
            name: "Salad",
            instructions: "Mix",
            prepTime: 10,
            cookTime: 0,
            servings: 2,
            at: .zero
        )

        _ = await model.addIngredient(
            toRecipe: recipe.id,
            name: "Lettuce",
            quantity: 1,
            unit: .whole,
            at: .zero
        )
        _ = await model.addIngredient(
            toRecipe: recipe.id,
            name: "Tomato",
            quantity: 2,
            unit: .whole,
            at: .zero
        )

        let ingredients = model.ingredients(in: recipe.id)
        #expect(ingredients.count == 2)
    }

    @Test("Query recipe for meal")
    @MainActor
    func testRecipeForMeal() async {
        let model = setupModel()

        let recipe = await model.addRecipe(
            name: "Curry",
            instructions: "Simmer",
            prepTime: 15,
            cookTime: 30,
            servings: 6,
            at: .zero
        )

        let meal = await model.addMeal(
            name: "Dinner",
            date: Date(),
            mealType: .dinner,
            servings: 6,
            recipeID: recipe.id,
            at: .zero
        )

        let foundRecipe = model.recipe(for: meal.id)
        #expect(foundRecipe?.id == recipe.id)
        #expect(foundRecipe?.name == "Curry")
    }

    @Test("Query tasks assigned to user")
    @MainActor
    func testTasksAssignedToUser() async {
        let model = setupModel()
        let userID = UUID()

        _ = await model.addTask(
            type: .shop,
            estimatedTime: 30,
            assignedUserID: userID,
            at: .zero
        )
        _ = await model.addTask(
            type: .cook,
            estimatedTime: 45,
            assignedUserID: userID,
            at: .zero
        )

        let tasks = model.tasks(assignedTo: userID)
        #expect(tasks.count == 2)
    }

    @Test("Generate shopping list aggregates ingredients")
    @MainActor
    func testGenerateShoppingList() async {
        let model = setupModel()

        // Create recipe 1
        let recipe1 = await model.addRecipe(
            name: "Pasta",
            instructions: "Cook",
            prepTime: 5,
            cookTime: 10,
            servings: 4,
            at: .zero
        )
        _ = await model.addIngredient(
            toRecipe: recipe1.id,
            name: "Spaghetti",
            quantity: 1,
            unit: .pound,
            at: .zero
        )
        _ = await model.addIngredient(
            toRecipe: recipe1.id,
            name: "Tomatoes",
            quantity: 3,
            unit: .whole,
            at: .zero
        )

        // Create recipe 2
        let recipe2 = await model.addRecipe(
            name: "Salad",
            instructions: "Mix",
            prepTime: 5,
            cookTime: 0,
            servings: 4,
            at: .zero
        )
        _ = await model.addIngredient(
            toRecipe: recipe2.id,
            name: "Tomatoes",
            quantity: 2,
            unit: .whole,
            at: .zero
        )

        // Create meals
        let meal1 = await model.addMeal(
            name: "Dinner 1",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            recipeID: recipe1.id,
            at: .zero
        )
        let meal2 = await model.addMeal(
            name: "Dinner 2",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            recipeID: recipe2.id,
            at: .zero
        )

        let shoppingList = model.generateShoppingList(for: [meal1.id, meal2.id])

        #expect(shoppingList.count == 2)
        #expect(shoppingList["Spaghetti"]?.0 == 1)
        #expect(shoppingList["Tomatoes"]?.0 == 5)  // 3 + 2 aggregated
    }
}
