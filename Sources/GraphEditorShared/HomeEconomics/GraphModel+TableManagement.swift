//
//  GraphModel+TableManagement.swift
//  GraphEditorShared
//
//  Table node management extensions for GraphModel
//

import Foundation
import CoreGraphics

@available(iOS 16.0, watchOS 9.0, *)
extension GraphModel {

    // MARK: - Table Node Management

    /// Adds a table node to the graph
    @MainActor
    public func addTable(
        name: String,
        headSeats: Int = 1,
        sideSeats: Int = 3,
        tableLength: CGFloat = 50.0,
        tableWidth: CGFloat = 30.0,
        at position: CGPoint
    ) async -> TableNode {
        let table = TableNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            headSeats: headSeats,
            sideSeats: sideSeats,
            tableLength: tableLength,
            tableWidth: tableWidth
        )

        nodes.append(AnyNode(table))
        nextNodeLabel += 1
        return table
    }

    /// Assigns a person to a seat at a table and positions the person node
    @MainActor
    public func assignPersonToTable(
        personID: NodeID,
        tableID: NodeID,
        seatIndex: Int
    ) async {
        // Get the table and person nodes
        guard let tableIndex = nodes.firstIndex(where: { $0.id == tableID }),
              var table = nodes[tableIndex].unwrapped as? TableNode,
              let personIndex = nodes.firstIndex(where: { $0.id == personID }),
              var person = nodes[personIndex].unwrapped as? PersonNode else {
            return
        }

        // Remove person from any previous seat
        table.seatingAssignments = table.seatingAssignments.filter { $0.value != personID }

        // Assign to new seat
        table.seatingAssignments[seatIndex] = personID

        // Calculate and set person's position
        let newPosition = table.seatPosition(for: seatIndex)
        person = person.with(position: newPosition, velocity: .zero)

        // Update both nodes
        nodes[tableIndex] = AnyNode(table)
        nodes[personIndex] = AnyNode(person)

        // Create association edge from table to person
        await addEdge(from: tableID, target: personID, type: .association)

        // Update cache
        updateCacheForAssignment(personID: personID, tableID: tableID)

        try? await saveGraph()
    }

    /// Removes a person from a table
    @MainActor
    public func removePersonFromTable(
        personID: NodeID,
        tableID: NodeID
    ) async {
        guard let tableIndex = nodes.firstIndex(where: { $0.id == tableID }),
              var table = nodes[tableIndex].unwrapped as? TableNode else {
            return
        }

        // Remove from seating assignments
        table.seatingAssignments = table.seatingAssignments.filter { $0.value != personID }
        nodes[tableIndex] = AnyNode(table)

        // Remove edge
        edges.removeAll { $0.from == tableID && $0.target == personID }

        // Update cache
        updateCacheForRemoval(personID: personID)

        try? await saveGraph()
    }

    /// Arranges all assigned persons around a table
    @MainActor
    public func arrangePersonsAroundTable(tableID: NodeID) {
        guard let tableIndex = nodes.firstIndex(where: { $0.id == tableID }),
              let table = nodes[tableIndex].unwrapped as? TableNode else {
            return
        }

        // Position each assigned person
        for (seatIndex, personID) in table.seatingAssignments {
            if let personIndex = nodes.firstIndex(where: { $0.id == personID }),
               var person = nodes[personIndex].unwrapped as? PersonNode {
                let newPosition = table.seatPosition(for: seatIndex)
                person = person.with(position: newPosition, velocity: .zero)
                nodes[personIndex] = AnyNode(person)
            }
        }
    }

    /// Updates a table's position and automatically repositions seated persons
    @MainActor
    public func updateTablePosition(tableID: NodeID, to position: CGPoint) {
        guard let tableIndex = nodes.firstIndex(where: { $0.id == tableID }),
              var table = nodes[tableIndex].unwrapped as? TableNode else {
            return
        }

        // Update table position
        table = table.with(position: position, velocity: .zero)
        nodes[tableIndex] = AnyNode(table)

        // Automatically rearrange seated persons
        arrangePersonsAroundTable(tableID: tableID)
    }
}
