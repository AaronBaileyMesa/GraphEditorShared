//
//  MealPlanningTypesTests.swift
//  GraphEditorSharedTests
//
//  Tests for meal planning domain types
//

import Testing
import Foundation
@testable import GraphEditorShared

struct MealPlanningTypesTests {

    @Test("MealType has all expected cases")
    func testMealTypeCases() {
        let allCases = MealType.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.breakfast))
        #expect(allCases.contains(.lunch))
        #expect(allCases.contains(.dinner))
        #expect(allCases.contains(.snack))
    }

    @Test("MealType is Codable")
    func testMealTypeCodable() throws {
        let type = MealType.dinner
        let encoded = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(MealType.self, from: encoded)
        #expect(decoded == .dinner)
    }

    @Test("TaskType has all workflow stages")
    func testTaskTypeCases() {
        let allCases = TaskType.allCases
        #expect(allCases.count == 15)
        // Top-level workflow stages
        #expect(allCases.contains(.plan))
        #expect(allCases.contains(.shop))
        #expect(allCases.contains(.prep))
        #expect(allCases.contains(.cook))
        #expect(allCases.contains(.assemble))
        #expect(allCases.contains(.serve))
        #expect(allCases.contains(.cleanup))
        // Prep subtasks
        #expect(allCases.contains(.prepMeat))
        #expect(allCases.contains(.prepVegetables))
        #expect(allCases.contains(.prepSauces))
        #expect(allCases.contains(.prepShells))
        #expect(allCases.contains(.prepToppings))
        // Assembly subtasks
        #expect(allCases.contains(.assemblySetup))
        #expect(allCases.contains(.assemblyBuild))
        #expect(allCases.contains(.assemblyPlate))
    }

    @Test("TaskStatus has all states")
    func testTaskStatusCases() {
        let allCases = TaskStatus.allCases
        #expect(allCases.count == 6)
        #expect(allCases.contains(.pending))
        #expect(allCases.contains(.inProgress))
        #expect(allCases.contains(.completed))
        #expect(allCases.contains(.skipped))
        #expect(allCases.contains(.blocked))
        #expect(allCases.contains(.declined))
    }

    @Test("MeasurementUnit has volume units")
    func testVolumeUnits() {
        #expect(MeasurementUnit.teaspoon.abbreviation == "tsp")
        #expect(MeasurementUnit.tablespoon.abbreviation == "tbsp")
        #expect(MeasurementUnit.cup.abbreviation == "cup")
        #expect(MeasurementUnit.liter.abbreviation == "L")
    }

    @Test("MeasurementUnit has weight units")
    func testWeightUnits() {
        #expect(MeasurementUnit.ounce.abbreviation == "oz")
        #expect(MeasurementUnit.pound.abbreviation == "lb")
        #expect(MeasurementUnit.gram.abbreviation == "g")
        #expect(MeasurementUnit.kilogram.abbreviation == "kg")
    }

    @Test("MeasurementUnit has count units")
    func testCountUnits() {
        #expect(MeasurementUnit.whole.abbreviation == "")
        #expect(MeasurementUnit.piece.abbreviation == "pc")
        #expect(MeasurementUnit.slice.abbreviation == "slice")
    }
}
