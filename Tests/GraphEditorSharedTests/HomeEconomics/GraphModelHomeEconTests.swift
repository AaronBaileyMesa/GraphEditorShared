//
//  GraphModelHomeEconTests.swift
//  GraphEditorSharedTests
//
//  Tests for GraphModel home economics extensions
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

@available(iOS 16.0, watchOS 9.0, *)
struct GraphModelHomeEconTests {

    @MainActor
    private func setupModel() -> GraphModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        return GraphModel(storage: storage, physicsEngine: physicsEngine)
    }

    @Test("Add transaction creates node with correct properties")
    @MainActor
    func testAddTransaction() async {
        let model = setupModel()

        let transaction = await model.addTransaction(
            amount: Decimal(45.32),
            description: "Groceries",
            type: .expense,
            at: .zero
        )

        #expect(transaction.amount == Decimal(45.32))
        #expect(transaction.transactionDescription == "Groceries")
        #expect(transaction.transactionType == .expense)
        #expect(model.nodes.count == 1)
    }

    @Test("Add transaction with category creates edge")
    @MainActor
    func testAddTransactionWithCategory() async {
        let model = setupModel()

        let category = await model.addCategory(
            name: "Food",
            color: .green,
            at: CGPoint(x: 100, y: 100)
        )

        let transaction = await model.addTransaction(
            amount: 50,
            description: "Lunch",
            type: .expense,
            categoryID: category.id,
            at: .zero
        )

        #expect(model.nodes.count == 2)
        #expect(model.edges.count == 1)

        let edge = model.edges.first!
        #expect(edge.from == transaction.id)
        #expect(edge.target == category.id)
        #expect(edge.type == .hierarchy)
    }

    @Test("Query transactions in category")
    @MainActor
    func testQueryTransactionsInCategory() async {
        let model = setupModel()

        let category = await model.addCategory(name: "Food", color: .green, at: .zero)

        _ = await model.addTransaction(
            amount: 10, description: "Coffee",
            type: .expense, categoryID: category.id, at: .zero
        )
        _ = await model.addTransaction(
            amount: 25, description: "Lunch",
            type: .expense, categoryID: category.id, at: .zero
        )

        let transactions = model.transactions(in: category.id)
        #expect(transactions.count == 2)
    }

    @Test("Calculate total spending in category")
    @MainActor
    func testTotalSpending() async {
        let model = setupModel()

        let category = await model.addCategory(name: "Transport", color: .blue, at: .zero)

        _ = await model.addTransaction(
            amount: 15.50, description: "Bus",
            type: .expense, categoryID: category.id, at: .zero
        )
        _ = await model.addTransaction(
            amount: 45.00, description: "Taxi",
            type: .expense, categoryID: category.id, at: .zero
        )

        let total = model.totalSpending(in: category.id)
        #expect(total == Decimal(60.50))
    }

    @Test("Income transactions excluded from spending total")
    @MainActor
    func testIncomeExcludedFromSpending() async {
        let model = setupModel()

        let category = await model.addCategory(name: "Work", color: .green, at: .zero)

        _ = await model.addTransaction(
            amount: 1000, description: "Salary",
            type: .income, categoryID: category.id, at: .zero
        )
        _ = await model.addTransaction(
            amount: 50, description: "Expense",
            type: .expense, categoryID: category.id, at: .zero
        )

        let total = model.totalSpending(in: category.id)
        #expect(total == Decimal(50))  // Income not counted
    }
}
