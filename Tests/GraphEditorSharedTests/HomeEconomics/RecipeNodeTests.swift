//
//  RecipeNodeTests.swift
//  GraphEditorSharedTests
//
//  Tests for RecipeNode conformance to NodeProtocol
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

struct RecipeNodeTests {

    @Test("RecipeNode initializes with correct properties")
    func testInitialization() {
        let recipe = RecipeNode(
            label: 1,
            position: CGPoint(x: 100, y: 200),
            name: "Spaghetti Carbonara",
            instructions: "1. Boil pasta...",
            prepTime: 10,
            cookTime: 15,
            servings: 4,
            difficulty: "easy"
        )

        #expect(recipe.label == 1)
        #expect(recipe.name == "Spaghetti Carbonara")
        #expect(recipe.instructions == "1. Boil pasta...")
        #expect(recipe.prepTime == 10)
        #expect(recipe.cookTime == 15)
        #expect(recipe.servings == 4)
        #expect(recipe.difficulty == "easy")
        #expect(recipe.isCollapsible == true)
        #expect(recipe.isExpanded == true)
    }

    @Test("RecipeNode has cyan fill color")
    func testFillColor() {
        let recipe = RecipeNode(
            label: 1, position: .zero, name: "Pasta",
            instructions: "Cook", prepTime: 10, cookTime: 20, servings: 4
        )

        #expect(recipe.fillColor == .cyan)
    }

    @Test("RecipeNode contents include name and total time")
    func testContents() {
        let recipe = RecipeNode(
            label: 1, position: .zero, name: "Quick Pasta",
            instructions: "Fast", prepTime: 5, cookTime: 10, servings: 2
        )

        #expect(recipe.contents.count == 2)

        // Verify string content (name)
        if case .string(let value) = recipe.contents[0] {
            #expect(value == "Quick Pasta")
        } else {
            Issue.record("Expected string content for name")
        }

        // Verify number content (total time)
        if case .number(let value) = recipe.contents[1] {
            #expect(value == 15.0)  // 5 + 10
        } else {
            Issue.record("Expected number content for total time")
        }
    }

    @Test("RecipeNode is Codable")
    func testCodable() throws {
        let original = RecipeNode(
            id: UUID(),
            label: 5,
            position: CGPoint(x: 50, y: 100),
            name: "Lasagna",
            instructions: "Layer and bake",
            prepTime: 30,
            cookTime: 60,
            servings: 8,
            difficulty: "hard"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecipeNode.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.label == original.label)
        #expect(decoded.name == original.name)
        #expect(decoded.instructions == original.instructions)
        #expect(decoded.prepTime == original.prepTime)
        #expect(decoded.cookTime == original.cookTime)
        #expect(decoded.servings == original.servings)
        #expect(decoded.difficulty == original.difficulty)
        #expect(decoded.velocity == .zero)  // Velocity reset on decode
    }

    @Test("RecipeNode works with AnyNode wrapper")
    func testAnyNodeWrapping() {
        let recipe = RecipeNode(
            label: 1, position: .zero, name: "Tacos",
            instructions: "Assemble", prepTime: 15, cookTime: 10, servings: 4
        )

        let anyNode = AnyNode(recipe)
        #expect(anyNode.id == recipe.id)
        #expect(anyNode.label == recipe.label)
        #expect(anyNode.fillColor == .cyan)

        // Test unwrapping
        if let unwrapped = anyNode.unwrapped as? RecipeNode {
            #expect(unwrapped.name == "Tacos")
            #expect(unwrapped.prepTime == 15)
        } else {
            Issue.record("Failed to unwrap RecipeNode")
        }
    }

    @Test("RecipeNode with() methods preserve immutability")
    func testWithMethods() {
        let original = RecipeNode(
            label: 1, position: CGPoint(x: 0, y: 0),
            name: "Soup", instructions: "Boil",
            prepTime: 5, cookTime: 20, servings: 4
        )

        let updated = original.with(
            position: CGPoint(x: 50, y: 50),
            velocity: CGPoint(x: 1, y: 1)
        )

        #expect(original.position == .zero)  // Original unchanged
        #expect(updated.position == CGPoint(x: 50, y: 50))
        #expect(updated.velocity == CGPoint(x: 1, y: 1))
        #expect(updated.id == original.id)  // ID preserved
        #expect(updated.name == original.name)  // Other properties preserved
    }

    @Test("RecipeNode collapse/expand behavior")
    func testCollapseExpand() {
        let recipe = RecipeNode(
            label: 1, position: .zero, name: "Curry",
            instructions: "Simmer", prepTime: 10, cookTime: 30, servings: 6
        )

        #expect(recipe.isExpanded == true)
        #expect(recipe.shouldHideChildren() == false)

        let collapsed = recipe.with(isExpanded: false)
        #expect(collapsed.isExpanded == false)
        #expect(collapsed.shouldHideChildren() == true)

        let tapped = collapsed.handlingTap()
        #expect(tapped.isExpanded == true)
        #expect(tapped.shouldHideChildren() == false)
    }
}
