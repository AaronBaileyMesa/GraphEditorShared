//
//  TableSeating.swift
//  GraphEditorShared
//
//  Represents a dining table seating arrangement
//

import Foundation
import SwiftUI

/// Represents a dining table with seating assignments
@available(iOS 16.0, watchOS 9.0, *)
public struct TableSeating: Codable {
    public let id: UUID
    public let mealID: NodeID  // The meal this seating is for
    public var assignments: [Int: NodeID]  // Seat index (0-11) to Person ID

    public init(
        id: UUID = UUID(),
        mealID: NodeID,
        assignments: [Int: NodeID] = [:]
    ) {
        self.id = id
        self.mealID = mealID
        self.assignments = assignments
    }
    
    /// Get the person assigned to a specific seat index
    public func person(at seatIndex: Int) -> NodeID? {
        assignments[seatIndex]
    }

    /// Assign a person to a seat index
    public mutating func assign(personID: NodeID, to seatIndex: Int) {
        assignments[seatIndex] = personID
    }

    /// Remove a person from their seat
    public mutating func remove(personID: NodeID) {
        assignments = assignments.filter { $0.value != personID }
    }

    /// Get all occupied seat indices
    public var occupiedSeats: [Int] {
        Array(assignments.keys).sorted()
    }

    /// Get all empty seat indices (up to maxSeats)
    public func emptySeats(maxSeats: Int) -> [Int] {
        (0..<maxSeats).filter { assignments[$0] == nil }
    }

    /// Check if a person is assigned to any seat
    public func isAssigned(personID: NodeID) -> Bool {
        assignments.values.contains(personID)
    }

    /// Get the seat index for a person
    public func seatIndex(for personID: NodeID) -> Int? {
        assignments.first(where: { $0.value == personID })?.key
    }
}
