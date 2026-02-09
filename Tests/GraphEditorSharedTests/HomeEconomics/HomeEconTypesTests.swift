//
//  HomeEconTypesTests.swift
//  GraphEditorSharedTests
//
//  Created for home economics feature
//

import Testing
@testable import GraphEditorShared

@available(iOS 16.0, watchOS 9.0, *)
struct HomeEconTypesTests {

    @Test("HomeEconNodeType has all expected cases")
    func testNodeTypeCases() {
        let allCases = HomeEconNodeType.allCases
        #expect(allCases.count == 6)
        #expect(allCases.contains(.transaction))
        #expect(allCases.contains(.category))
        #expect(allCases.contains(.budget))
        #expect(allCases.contains(.user))
        #expect(allCases.contains(.account))
        #expect(allCases.contains(.goal))
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
