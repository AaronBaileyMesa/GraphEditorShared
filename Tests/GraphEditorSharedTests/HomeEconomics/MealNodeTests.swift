//
//  MealNodeTests.swift
//  GraphEditorSharedTests
//
//  Tests for MealNode conformance to NodeProtocol
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

@available(iOS 16.0, watchOS 9.0, *)
struct MealNodeTests {

    @Test("MealNode initializes with correct properties")
    func testInitialization() {
        let date = Date()
        let meal = MealNode(
            label: 1,
            position: CGPoint(x: 100, y: 200),
            name: "Monday Dinner",
            date: date,
            mealType: .dinner,
            servings: 4
        )

        #expect(meal.label == 1)
        #expect(meal.name == "Monday Dinner")
        #expect(meal.date == date)
        #expect(meal.mealType == .dinner)
        #expect(meal.servings == 4)
    }

    @Test("MealNode has correct fill color by meal type")
    func testFillColorByType() {
        let breakfast = MealNode(
            label: 1, position: .zero, name: "Breakfast",
            date: Date(), mealType: .breakfast, servings: 2
        )
        let dinner = MealNode(
            label: 2, position: .zero, name: "Dinner",
            date: Date(), mealType: .dinner, servings: 4
        )

        // Colors should be different per meal type
        #expect(breakfast.fillColor == .orange)
        #expect(dinner.fillColor == .purple)
    }

    @Test("MealNode contents include name and date")
    func testContents() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let meal = MealNode(
            label: 1, position: .zero, name: "Taco Tuesday",
            date: date, mealType: .dinner, servings: 3
        )

        #expect(meal.contents.count == 2)

        // Verify string content
        if case .string(let value) = meal.contents[0] {
            #expect(value == "Taco Tuesday")
        } else {
            Issue.record("Expected string content for name")
        }

        // Verify date content
        if case .date(let value) = meal.contents[1] {
            #expect(value == date)
        } else {
            Issue.record("Expected date content")
        }
    }

    @Test("MealNode is Codable")
    func testCodable() throws {
        let original = MealNode(
            id: UUID(),
            label: 5,
            position: CGPoint(x: 50, y: 100),
            name: "Sunday Brunch",
            date: Date(),
            mealType: .breakfast,
            servings: 6,
            recipeID: UUID()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MealNode.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.label == original.label)
        #expect(decoded.name == original.name)
        #expect(decoded.mealType == original.mealType)
        #expect(decoded.servings == original.servings)
        #expect(decoded.recipeID == original.recipeID)
    }

    @Test("MealNode works with AnyNode wrapper")
    func testAnyNodeWrapping() {
        let meal = MealNode(
            label: 1, position: .zero, name: "Lunch",
            date: Date(), mealType: .lunch, servings: 2
        )

        let anyNode = AnyNode(meal)
        #expect(anyNode.id == meal.id)
        #expect(anyNode.label == meal.label)

        // Test unwrapping
        if let unwrapped = anyNode.unwrapped as? MealNode {
            #expect(unwrapped.name == "Lunch")
            #expect(unwrapped.mealType == .lunch)
        } else {
            Issue.record("Failed to unwrap MealNode")
        }
    }

    @Test("MealNode with() preserves immutability")
    func testWithMethods() {
        let original = MealNode(
            label: 1, position: CGPoint(x: 0, y: 0),
            name: "Dinner", date: Date(),
            mealType: .dinner, servings: 4
        )

        let updated = original.with(
            position: CGPoint(x: 50, y: 50),
            velocity: CGPoint(x: 1, y: 1)
        )

        #expect(original.position == .zero)  // Original unchanged
        #expect(updated.position == CGPoint(x: 50, y: 50))
        #expect(updated.id == original.id)  // ID preserved
    }
}
