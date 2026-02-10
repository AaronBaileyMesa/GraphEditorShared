//
//  IngredientNodeTests.swift
//  GraphEditorSharedTests
//
//  Tests for IngredientNode conformance to NodeProtocol
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

@available(iOS 16.0, watchOS 9.0, *)
struct IngredientNodeTests {

    @Test("IngredientNode initializes with correct properties")
    func testInitialization() {
        let ingredient = IngredientNode(
            label: 1,
            position: CGPoint(x: 100, y: 200),
            name: "Eggs",
            quantity: 4,
            unit: .whole
        )

        #expect(ingredient.label == 1)
        #expect(ingredient.name == "Eggs")
        #expect(ingredient.quantity == 4)
        #expect(ingredient.unit == .whole)
        #expect(ingredient.isCollapsible == false)
        #expect(ingredient.children.isEmpty)
    }

    @Test("IngredientNode displayString formats correctly")
    func testDisplayString() {
        let eggs = IngredientNode(
            label: 1, position: .zero, name: "eggs",
            quantity: 4, unit: .whole
        )
        let flour = IngredientNode(
            label: 2, position: .zero, name: "flour",
            quantity: 2, unit: .cup
        )
        let singleEgg = IngredientNode(
            label: 3, position: .zero, name: "egg",
            quantity: 1, unit: .whole
        )

        // 4 eggs should show "4 eggs"
        #expect(eggs.displayString.contains("4"))
        #expect(eggs.displayString.contains("eggs"))

        // 2 cups flour should show "2 cup flour"
        #expect(flour.displayString.contains("2"))
        #expect(flour.displayString.contains("cup"))
        #expect(flour.displayString.contains("flour"))

        // 1 egg (with .whole unit) should just show "egg"
        #expect(singleEgg.displayString == "egg" || singleEgg.displayString.contains("egg"))
    }

    @Test("IngredientNode contents include name, quantity, and unit")
    func testContents() {
        let ingredient = IngredientNode(
            label: 1, position: .zero, name: "butter",
            quantity: 0.5, unit: .cup
        )

        #expect(ingredient.contents.count == 3)

        // Verify string content (name)
        if case .string(let value) = ingredient.contents[0] {
            #expect(value == "butter")
        } else {
            Issue.record("Expected string content for name")
        }

        // Verify number content (quantity)
        if case .number(let value) = ingredient.contents[1] {
            #expect(value == 0.5)
        } else {
            Issue.record("Expected number content for quantity")
        }

        // Verify string content (unit abbreviation)
        if case .string(let value) = ingredient.contents[2] {
            #expect(value == "cup")
        } else {
            Issue.record("Expected string content for unit")
        }
    }

    @Test("IngredientNode is Codable with Decimal serialization")
    func testCodable() throws {
        let original = IngredientNode(
            id: UUID(),
            label: 5,
            position: CGPoint(x: 50, y: 100),
            name: "sugar",
            quantity: Decimal(string: "1.25")!,
            unit: .cup
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IngredientNode.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.label == original.label)
        #expect(decoded.name == original.name)
        #expect(decoded.quantity == original.quantity)
        #expect(decoded.unit == original.unit)
        #expect(decoded.velocity == .zero)  // Velocity reset on decode
    }

    @Test("IngredientNode is not collapsible")
    func testNotCollapsible() {
        let ingredient = IngredientNode(
            label: 1, position: .zero, name: "salt",
            quantity: 1, unit: .teaspoon
        )

        #expect(ingredient.isCollapsible == false)
        #expect(ingredient.shouldHideChildren() == false)

        // Tap should have no effect
        let afterTap = ingredient.handlingTap()
        #expect(afterTap.isExpanded == ingredient.isExpanded)
    }

    @Test("IngredientNode works with AnyNode wrapper")
    func testAnyNodeWrapping() {
        let ingredient = IngredientNode(
            label: 1, position: .zero, name: "olive oil",
            quantity: 2, unit: .tablespoon
        )

        let anyNode = AnyNode(ingredient)
        #expect(anyNode.id == ingredient.id)
        #expect(anyNode.label == ingredient.label)
        #expect(anyNode.fillColor == .green)

        // Test unwrapping
        if let unwrapped = anyNode.unwrapped as? IngredientNode {
            #expect(unwrapped.name == "olive oil")
            #expect(unwrapped.quantity == 2)
            #expect(unwrapped.unit == .tablespoon)
        } else {
            Issue.record("Failed to unwrap IngredientNode")
        }
    }
}
