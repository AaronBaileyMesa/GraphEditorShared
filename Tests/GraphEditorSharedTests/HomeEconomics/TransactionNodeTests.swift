//
//  TransactionNodeTests.swift
//  GraphEditorSharedTests
//
//  Tests for TransactionNode conformance to NodeProtocol
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

struct TransactionNodeTests {

    @Test("TransactionNode initializes with correct properties")
    func testInitialization() {
        let node = TransactionNode(
            label: 1,
            position: CGPoint(x: 100, y: 200),
            amount: Decimal(45.32),
            transactionDate: Date(),
            description: "Groceries",
            transactionType: .expense
        )

        #expect(node.label == 1)
        #expect(node.amount == Decimal(45.32))
        #expect(node.transactionDescription == "Groceries")
        #expect(node.transactionType == .expense)
    }

    @Test("TransactionNode has correct fill color")
    func testFillColor() {
        let income = TransactionNode(
            label: 1, position: .zero, amount: 100,
            transactionDate: Date(), description: "Salary",
            transactionType: .income
        )
        let expense = TransactionNode(
            label: 2, position: .zero, amount: 50,
            transactionDate: Date(), description: "Gas",
            transactionType: .expense
        )

        #expect(income.fillColor == .green)
        #expect(expense.fillColor == .red)
    }

    @Test("TransactionNode contents are populated")
    func testContents() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let node = TransactionNode(
            label: 1, position: .zero, amount: Decimal(123.45),
            transactionDate: date, description: "Test transaction",
            transactionType: .expense
        )

        #expect(node.contents.count == 3)

        // Verify number content
        if case .number(let value) = node.contents[0] {
            #expect(abs(value - 123.45) < 0.01)
        } else {
            Issue.record("Expected number content")
        }

        // Verify date content
        if case .date(let value) = node.contents[1] {
            #expect(value == date)
        } else {
            Issue.record("Expected date content")
        }

        // Verify string content
        if case .string(let value) = node.contents[2] {
            #expect(value == "Test transaction")
        } else {
            Issue.record("Expected string content")
        }
    }

    @Test("TransactionNode is Codable")
    func testCodable() throws {
        let original = TransactionNode(
            id: UUID(),
            label: 5,
            position: CGPoint(x: 50, y: 100),
            amount: Decimal(99.99),
            transactionDate: Date(),
            description: "Test",
            transactionType: .income,
            categoryID: UUID(),
            payerID: UUID()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransactionNode.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.label == original.label)
        #expect(decoded.amount == original.amount)
        #expect(decoded.transactionType == original.transactionType)
        #expect(decoded.categoryID == original.categoryID)
        #expect(decoded.payerID == original.payerID)
    }

    @Test("TransactionNode works with AnyNode wrapper")
    func testAnyNodeWrapping() throws {
        let transaction = TransactionNode(
            label: 1, position: .zero, amount: 50,
            transactionDate: Date(), description: "Coffee",
            transactionType: .expense
        )

        let anyNode = AnyNode(transaction)
        #expect(anyNode.id == transaction.id)
        #expect(anyNode.label == transaction.label)

        // Test unwrapping
        if let unwrapped = anyNode.unwrapped as? TransactionNode {
            #expect(unwrapped.amount == Decimal(50))
        } else {
            Issue.record("Failed to unwrap TransactionNode")
        }
    }

    @Test("TransactionNode with() preserves immutability")
    func testWithMethods() {
        let original = TransactionNode(
            label: 1, position: CGPoint(x: 0, y: 0),
            amount: 100, transactionDate: Date(),
            description: "Original", transactionType: .expense
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
