//
//  GraphModel+PeopleList.swift
//  GraphEditorShared
//
//  PeopleListNode lifecycle and management
//

import Foundation
import CoreGraphics
import SwiftUI

@available(iOS 16.0, watchOS 9.0, *)
extension GraphModel {

    // MARK: - PeopleListNode Lifecycle

    /// Ensures a PeopleListNode exists as a child of RootNode. Creates one if missing.
    @MainActor
    public func ensurePeopleListNode() async {
        // Check if PeopleListNode already exists
        if nodes.contains(where: { $0.unwrapped is PeopleListNode }) {
            return
        }

        guard let rootNode = getRootNode() else {
            // Can't create people list without a root
            return
        }

        // Find next available label
        let maxLabel = nodes.map { $0.label }.max() ?? 0
        let newLabel = maxLabel + 1

        // Create PeopleListNode at radial position from root
        let position = getNextChildPosition(from: rootNode.id, distance: 80.0)

        let peopleList = PeopleListNode(
            label: newLabel,
            position: position,
            name: "People"
        )

        nodes.append(AnyNode(peopleList))

        // Create hierarchy edge from root to people list
        await addEdge(from: rootNode.id, target: peopleList.id, type: .hierarchy)

        objectWillChange.send()
        pushUndo()
    }

    /// Returns the PeopleListNode if it exists
    @MainActor
    public func getPeopleListNode() -> PeopleListNode? {
        return nodes.first(where: { $0.unwrapped is PeopleListNode })?.unwrapped as? PeopleListNode
    }

    /// Returns the index of the PeopleListNode in the nodes array
    @MainActor
    private func getPeopleListNodeIndex() -> Int? {
        return nodes.firstIndex(where: { $0.unwrapped is PeopleListNode })
    }

    // MARK: - Person Management with PeopleListNode

    /// Creates a PersonNode as a child of PeopleListNode at smart radial position
    @MainActor
    public func addPersonToPeopleList() async -> PersonNode {
        // Ensure people list exists
        await ensurePeopleListNode()

        guard let peopleList = getPeopleListNode(),
              let peopleListIndex = getPeopleListNodeIndex() else {
            fatalError("PeopleListNode must exist after ensurePeopleListNode")
        }

        // Calculate position relative to people list
        let position = getNextChildPosition(from: peopleList.id, distance: 50.0)

        let person = await addPerson(
            name: "New Person",
            defaultSpiceLevel: nil,
            dietaryRestrictions: [],
            at: position
        )

        // Create hierarchy edge from people list to person
        await addEdge(from: peopleList.id, target: person.id, type: .hierarchy)

        // Update people list to include new child
        var updatedPeopleList = peopleList
        updatedPeopleList.children.append(person.id)
        updatedPeopleList.childOrder.append(person.id)
        nodes[peopleListIndex] = AnyNode(updatedPeopleList)

        // Apply constraints immediately to position the person correctly in the table
        await applyConstraintsToNode(person.id)

        objectWillChange.send()
        pushUndo()

        return person
    }

    /// Migrates existing PersonNodes from root to PeopleListNode
    @MainActor
    public func migratePeopleToPeopleList() async {
        // Ensure people list exists
        await ensurePeopleListNode()

        guard let rootNode = getRootNode(),
              let peopleList = getPeopleListNode(),
              let peopleListIndex = getPeopleListNodeIndex() else {
            return
        }

        // Find all PersonNodes that are direct children of root
        let personNodes = nodes.compactMap { $0.unwrapped as? PersonNode }
        let rootHierarchyEdges = edges.filter { $0.from == rootNode.id && $0.type == .hierarchy }
        let rootChildPersonIDs = personNodes.filter { person in
            rootHierarchyEdges.contains { $0.target == person.id }
        }.map { $0.id }

        guard !rootChildPersonIDs.isEmpty else {
            // No people to migrate
            return
        }

        var updatedPeopleList = peopleList

        // Move each person from root to people list
        for personID in rootChildPersonIDs {
            // Remove edge from root to person
            edges.removeAll { $0.from == rootNode.id && $0.target == personID && $0.type == .hierarchy }

            // Add edge from people list to person
            await addEdge(from: peopleList.id, target: personID, type: .hierarchy)

            // Add to people list children
            if !updatedPeopleList.children.contains(personID) {
                updatedPeopleList.children.append(personID)
                updatedPeopleList.childOrder.append(personID)
            }
        }

        // Update people list node
        nodes[peopleListIndex] = AnyNode(updatedPeopleList)

        objectWillChange.send()
        pushUndo()
    }

    /// Arranges PersonNodes in a cluster around PeopleListNode
    @MainActor
    public func arrangePeopleAroundList() {
        guard let peopleList = getPeopleListNode() else { return }

        let personIDs = peopleList.children
        let personNodes = nodes.filter { personIDs.contains($0.id) }

        guard !personNodes.isEmpty else { return }

        // Arrange in a radial pattern around the people list
        let angleStep = 360.0 / Double(personNodes.count)
        let radius: CGFloat = 50.0

        for (index, personNode) in personNodes.enumerated() {
            let angle = Double(index) * angleStep
            let angleRad = angle * .pi / 180.0

            let newPosition = CGPoint(
                x: peopleList.position.x + radius * cos(angleRad),
                y: peopleList.position.y + radius * sin(angleRad)
            )

            if let nodeIndex = nodes.firstIndex(where: { $0.id == personNode.id }) {
                nodes[nodeIndex] = AnyNode(personNode.unwrapped.with(
                    position: newPosition,
                    velocity: .zero
                ))
            }
        }

        objectWillChange.send()
        pushUndo()
    }

    // MARK: - Private Helpers

    /// Applies constraints to a specific node immediately (without waiting for physics simulation)
    @MainActor
    private func applyConstraintsToNode(_ nodeID: NodeID) async {
        guard let nodeIndex = nodes.firstIndex(where: { $0.id == nodeID }) else {
            return
        }
        
        let node = nodes[nodeIndex].unwrapped
        
        // Collect all constraints from all nodes
        var allConstraints: [NodeConstraint] = []
        for n in nodes {
            let constraints = n.unwrapped.typeDescriptor.constraints
            allConstraints.append(contentsOf: constraints)
        }
        
        // Find constraints that affect this node
        let constraintsForNode = allConstraints.filter { constraint in
            constraint.affectedNodeIDs().contains(nodeID)
        }
        
        guard !constraintsForNode.isEmpty else {
            return
        }
        
        // Create constraint context
        let constraintContext = ConstraintContext(
            allNodes: nodes.map { $0.unwrapped },
            deltaTime: Constants.Physics.timeStep,
            simulationBounds: physicsEngine.simulationBounds,
            originalPositions: [:]
        )
        
        // Apply each constraint
        var constrainedPosition = node.position
        for constraint in constraintsForNode {
            if let newPos = constraint.apply(
                to: node,
                proposedPosition: constrainedPosition,
                context: constraintContext
            ) {
                constrainedPosition = newPos
            }
        }
        
        // Update the node with the constrained position
        nodes[nodeIndex] = AnyNode(node.with(position: constrainedPosition, velocity: .zero))
    }

    /// Calculates the next available radial position around a parent node for a new child
    @MainActor
    private func getNextChildPosition(from parentID: NodeID, distance: CGFloat) -> CGPoint {
        guard let parent = nodes.first(where: { $0.id == parentID }) else {
            return CGPoint(x: distance, y: 0)
        }

        // Get all existing children of parent
        let childIDs = edges.filter { $0.from == parentID && $0.type == .hierarchy }.map { $0.target }
        let childPositions = nodes.filter { childIDs.contains($0.id) }.map { $0.position }

        // Preferred angles in degrees: right, down, left, up, then diagonals
        let preferredAngles: [CGFloat] = [0, 90, 180, 270, 45, 135, 225, 315]

        // Find first angle that doesn't have a child nearby
        for angle in preferredAngles {
            let angleRad = angle * .pi / 180
            let candidatePos = CGPoint(
                x: parent.position.x + distance * cos(angleRad),
                y: parent.position.y + distance * sin(angleRad)
            )

            // Check if this position is clear (no child within 40pt)
            let isClear = childPositions.allSatisfy { existingPos in
                let dx = existingPos.x - candidatePos.x
                let dy = existingPos.y - candidatePos.y
                let dist = sqrt(dx * dx + dy * dy)
                return dist > 40.0
            }

            if isClear {
                return candidatePos
            }
        }

        // If all positions occupied, use right with slight random offset
        let randomOffset = CGFloat.random(in: -15...15)
        return CGPoint(x: parent.position.x + distance, y: parent.position.y + randomOffset)
    }
}
