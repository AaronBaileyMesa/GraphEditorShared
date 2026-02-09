//
//  HomeEconTypes.swift
//  GraphEditorShared
//
//  Core domain types for home economics tracking
//

import Foundation

/// Domain-specific node types for home economics tracking
@available(iOS 16.0, watchOS 9.0, *)
public enum HomeEconNodeType: String, Codable, CaseIterable {
    case transaction    // Income or expense record
    case category       // Spending category (groceries, utilities, etc.)
    case budget         // Monthly/weekly budget limit for a category
    case user           // Household member
    case account        // Bank account or credit card
    case goal           // Savings goal
}

/// Transaction classification
@available(iOS 16.0, watchOS 9.0, *)
public enum TransactionType: String, Codable {
    case income
    case expense
}

/// Budget period
@available(iOS 16.0, watchOS 9.0, *)
public enum BudgetPeriod: String, Codable, CaseIterable {
    case weekly
    case monthly
    case yearly
}
