//
//  GraphModel+RootNode.swift
//  GraphEditorShared
//
//  RootNode lifecycle and child creation with smart positioning
//

import Foundation
import CoreGraphics
import SwiftUI

@available(iOS 16.0, watchOS 9.0, *)
extension GraphModel {
    
    // MARK: - RootNode Lifecycle
    
    /// Ensures a RootNode exists at (0, 0). Creates one if missing.
    @MainActor
    public func ensureRootNode() async {
        // Check if RootNode already exists
        if nodes.contains(where: { $0.unwrapped is RootNode }) {
            return
        }
        
        // Create RootNode with appropriate name
        let graphName = currentGraphName == "default" ? "root" : currentGraphName
        let rootNode = RootNode(name: graphName)
        
        nodes.append(AnyNode(rootNode))
        
        objectWillChange.send()
        pushUndo()
    }
    
    /// Returns the RootNode if it exists
    @MainActor
    public func getRootNode() -> RootNode? {
        return nodes.first(where: { $0.unwrapped is RootNode })?.unwrapped as? RootNode
    }
    
    // MARK: - Smart Radial Positioning
    
    /// Calculates the next available radial position around RootNode for a new child
    /// Uses cardinal directions first (right, down, left, up), then diagonals
    @MainActor
    private func getNextChildPosition(from rootID: NodeID, distance: CGFloat = 80.0) -> CGPoint {
        // Get all existing children of root
        let childIDs = edges.filter { $0.from == rootID && $0.type == .hierarchy }.map { $0.target }
        let childPositions = nodes.filter { childIDs.contains($0.id) }.map { $0.position }
        
        // Preferred angles in degrees: right, down, left, up, then diagonals
        let preferredAngles: [CGFloat] = [0, 90, 180, 270, 45, 135, 225, 315]
        
        // Find first angle that doesn't have a child nearby
        for angle in preferredAngles {
            let angleRad = angle * .pi / 180
            let candidatePos = CGPoint(
                x: distance * cos(angleRad),
                y: distance * sin(angleRad)
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
        return CGPoint(x: distance, y: randomOffset)
    }
    
    // MARK: - Child Creation from RootNode
    
    /// Creates a PersonNode as a child of PeopleListNode at smart radial position
    /// Automatically creates PeopleListNode if it doesn't exist
    @MainActor
    public func addPersonFromRoot() async -> PersonNode {
        // This now delegates to the PeopleListNode approach
        return await addPersonToPeopleList()
    }
    
    /// Creates a MealNode as a child of RootNode at smart radial position
    @MainActor
    public func addMealFromRoot() async -> MealNode {
        guard let rootNode = getRootNode() else {
            fatalError("RootNode must exist before adding children")
        }
        
        let position = getNextChildPosition(from: rootNode.id)
        
        let meal = await addMeal(
            name: "New Meal",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            at: position
        )
        
        // Create hierarchy edge from root to meal
        await addEdge(from: rootNode.id, target: meal.id, type: .hierarchy)
        
        return meal
    }
}
