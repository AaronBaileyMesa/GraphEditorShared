//
//  TableSeating.swift
//  GraphEditorShared
//
//  Represents a dining table seating arrangement
//

import Foundation
import SwiftUI

/// Position at a dining table
@available(iOS 16.0, watchOS 9.0, *)
public enum SeatPosition: String, Codable, CaseIterable {
    case head
    case foot
    case leftFront
    case leftMiddle
    case leftBack
    case rightFront
    case rightMiddle
    case rightBack
    
    /// Human-readable label for the seat
    public var label: String {
        switch self {
        case .head: return "Head"
        case .foot: return "Foot"
        case .leftFront: return "Left Front"
        case .leftMiddle: return "Left Middle"
        case .leftBack: return "Left Back"
        case .rightFront: return "Right Front"
        case .rightMiddle: return "Right Middle"
        case .rightBack: return "Right Back"
        }
    }
    
    /// Visual position for layout (normalized 0-1 coordinates)
    public var layoutPosition: CGPoint {
        switch self {
        case .head:
            return CGPoint(x: 0.5, y: 0.0)
        case .foot:
            return CGPoint(x: 0.5, y: 1.0)
        case .leftFront:
            return CGPoint(x: 0.2, y: 0.25)
        case .leftMiddle:
            return CGPoint(x: 0.2, y: 0.5)
        case .leftBack:
            return CGPoint(x: 0.2, y: 0.75)
        case .rightFront:
            return CGPoint(x: 0.8, y: 0.25)
        case .rightMiddle:
            return CGPoint(x: 0.8, y: 0.5)
        case .rightBack:
            return CGPoint(x: 0.8, y: 0.75)
        }
    }
}

/// Represents a dining table with seating assignments
@available(iOS 16.0, watchOS 9.0, *)
public struct TableSeating: Codable {
    public let id: UUID
    public let mealID: NodeID  // The meal this seating is for
    public var assignments: [SeatPosition: NodeID]  // Person ID for each seat
    
    public init(
        id: UUID = UUID(),
        mealID: NodeID,
        assignments: [SeatPosition: NodeID] = [:]
    ) {
        self.id = id
        self.mealID = mealID
        self.assignments = assignments
    }
    
    /// Get the person assigned to a specific seat
    public func person(at position: SeatPosition) -> NodeID? {
        assignments[position]
    }
    
    /// Assign a person to a seat
    public mutating func assign(personID: NodeID, to position: SeatPosition) {
        assignments[position] = personID
    }
    
    /// Remove a person from their seat
    public mutating func remove(personID: NodeID) {
        assignments = assignments.filter { $0.value != personID }
    }
    
    /// Get all assigned seats
    public var occupiedSeats: [SeatPosition] {
        Array(assignments.keys).sorted { $0.rawValue < $1.rawValue }
    }
    
    /// Get all empty seats
    public var emptySeats: [SeatPosition] {
        SeatPosition.allCases.filter { assignments[$0] == nil }
    }
    
    /// Check if a person is assigned to any seat
    public func isAssigned(personID: NodeID) -> Bool {
        assignments.values.contains(personID)
    }
    
    /// Get the seat position for a person
    public func position(for personID: NodeID) -> SeatPosition? {
        assignments.first(where: { $0.value == personID })?.key
    }
}
