//
//  HomeEconTypesTests.swift
//  GraphEditorSharedTests
//
//  Created for home economics feature
//

import Testing
import Foundation
@testable import GraphEditorShared

struct HomeEconTypesTests {

    @Test("HomeEconNodeType has all expected cases")
    func testNodeTypeCases() {
        let allCases = HomeEconNodeType.allCases
        #expect(allCases.count == 16)
        // Financial tracking
        #expect(allCases.contains(.transaction))
        #expect(allCases.contains(.category))
        #expect(allCases.contains(.budget))
        #expect(allCases.contains(.user))
        #expect(allCases.contains(.account))
        #expect(allCases.contains(.goal))
        // Meal planning
        #expect(allCases.contains(.meal))
        #expect(allCases.contains(.recipe))
        #expect(allCases.contains(.ingredient))
        #expect(allCases.contains(.shoppingItem))
        #expect(allCases.contains(.task))
        #expect(allCases.contains(.mealPlan))
        // Decision tree & preferences
        #expect(allCases.contains(.person))
        #expect(allCases.contains(.preference))
        #expect(allCases.contains(.decision))
        #expect(allCases.contains(.choice))
    }

    @Test("HomeEconNodeType is Codable")
    func testNodeTypeCodable() throws {
        let type = HomeEconNodeType.transaction
        let encoded = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(HomeEconNodeType.self, from: encoded)
        #expect(decoded == .transaction)
    }

    @Test("TransactionType encodes correctly")
    func testTransactionTypeCodable() throws {
        let income = TransactionType.income
        let encoded = try JSONEncoder().encode(income)
        let decoded = try JSONDecoder().decode(TransactionType.self, from: encoded)
        #expect(decoded == .income)
    }

    @Test("BudgetPeriod has all periods")
    func testBudgetPeriods() {
        let allCases = BudgetPeriod.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.weekly))
        #expect(allCases.contains(.monthly))
        #expect(allCases.contains(.yearly))
    }
}
