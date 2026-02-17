//
//  GraphModel+DecisionTree.swift
//  GraphEditorShared
//
//  Decision tree extensions for GraphModel
//

import Foundation
import CoreGraphics
import SwiftUI

@available(iOS 16.0, watchOS 9.0, *)
extension GraphModel {
    
    // MARK: - Person Operations
    
    /// Adds a person node (household member or guest)
    @MainActor
    public func addPerson(
        name: String,
        defaultSpiceLevel: String? = nil,
        dietaryRestrictions: [String] = [],
        proteinPreference: ProteinType? = nil,
        shellPreference: ShellType? = nil,
        toppingPreferences: [String] = [],
        at position: CGPoint
    ) async -> PersonNode {
        let person = PersonNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            defaultSpiceLevel: defaultSpiceLevel,
            dietaryRestrictions: dietaryRestrictions,
            proteinPreference: proteinPreference,
            shellPreference: shellPreference,
            toppingPreferences: toppingPreferences
        )
        
        nodes.append(AnyNode(person))
        nextNodeLabel += 1
        
        return person
    }
    
    // MARK: - Decision Node Operations
    
    /// Adds a decision node to the graph
    @MainActor
    public func addDecision(
        question: String,
        preferenceKey: String,
        inputType: DecisionInputType,
        at position: CGPoint
    ) async -> DecisionNode {
        let decision = DecisionNode(
            label: nextNodeLabel,
            position: position,
            question: question,
            preferenceKey: preferenceKey,
            inputType: inputType
        )
        
        nodes.append(AnyNode(decision))
        nextNodeLabel += 1
        
        return decision
    }
    
    /// Adds a choice node as a child of a decision node
    @MainActor
    public func addChoice(
        to decisionID: NodeID,
        choiceText: String,
        value: PreferenceValue,
        at position: CGPoint
    ) async -> ChoiceNode? {
        // Find the decision node
        guard let decisionIndex = nodes.firstIndex(where: { $0.id == decisionID }),
              var decision = nodes[decisionIndex].unwrapped as? DecisionNode else {
            return nil
        }
        
        let choice = ChoiceNode(
            label: nextNodeLabel,
            position: position,
            choiceText: choiceText,
            value: value
        )
        
        nodes.append(AnyNode(choice))
        nextNodeLabel += 1
        
        // Add choice as child of decision (hierarchy edge)
        decision.children.append(choice.id)
        decision.childOrder.append(choice.id)
        nodes[decisionIndex] = AnyNode(decision)
        
        await addEdge(from: decisionID, target: choice.id, type: .hierarchy)
        
        return choice
    }
    
    // MARK: - Decision Tree Navigation
    
    /// Links two decisions with a precedes edge (decision1 → decision2)
    @MainActor
    public func linkDecisions(from firstID: NodeID, to secondID: NodeID) async {
        await addEdge(from: firstID, target: secondID, type: .precedes)
    }
    
    /// Selects a choice within a decision (for singleChoice type)
    @MainActor
    public func selectChoice(_ choiceID: NodeID, in decisionID: NodeID) async -> Bool {
        guard let decisionIndex = nodes.firstIndex(where: { $0.id == decisionID }),
              var decision = nodes[decisionIndex].unwrapped as? DecisionNode else {
            return false
        }
        
        // Get child choices via hierarchy edges (same as we do when loading)
        let childIDs = edges
            .filter { $0.from == decisionID && $0.type == .hierarchy }
            .map { $0.target }
        
        // Verify choice is a child of this decision
        guard childIDs.contains(choiceID) else {
            return false
        }
        
        if decision.inputType == .singleChoice {
            // Deselect all other choices
            for childID in childIDs {
                if let choiceIndex = nodes.firstIndex(where: { $0.id == childID }),
                   var choice = nodes[choiceIndex].unwrapped as? ChoiceNode {
                    choice.isSelected = (childID == choiceID)
                    nodes[choiceIndex] = AnyNode(choice)
                }
            }
            
            decision.selectedChoiceID = choiceID
            decision.selectedChoiceIDs = [choiceID]
        } else if decision.inputType == .multiChoice {
            // Toggle selection
            if let choiceIndex = nodes.firstIndex(where: { $0.id == choiceID }),
               var choice = nodes[choiceIndex].unwrapped as? ChoiceNode {
                choice.isSelected.toggle()
                nodes[choiceIndex] = AnyNode(choice)
                
                // Update decision's selected list
                if choice.isSelected {
                    if !decision.selectedChoiceIDs.contains(choiceID) {
                        decision.selectedChoiceIDs.append(choiceID)
                    }
                } else {
                    decision.selectedChoiceIDs.removeAll { $0 == choiceID }
                }
            }
        }
        
        nodes[decisionIndex] = AnyNode(decision)
        return true
    }
    
    /// Sets a numeric value for a numeric decision
    @MainActor
    public func setNumericValue(_ value: Double, for decisionID: NodeID) async -> Bool {
        guard let decisionIndex = nodes.firstIndex(where: { $0.id == decisionID }),
              var decision = nodes[decisionIndex].unwrapped as? DecisionNode else {
            return false
        }
        
        guard decision.inputType == .numeric else {
            return false
        }
        
        decision.numericValue = value
        nodes[decisionIndex] = AnyNode(decision)
        return true
    }
    
    /// Gets the next decision following the given decision via precedes edges
    @MainActor
    public func getNextDecision(after decisionID: NodeID) -> DecisionNode? {
        // Find precedes edge from this decision
        guard let precedesEdge = edges.first(where: {
            $0.type == .precedes && $0.from == decisionID
        }) else {
            return nil
        }
        
        // Get the target decision
        guard let nextNode = nodes.first(where: { $0.id == precedesEdge.target }),
              let nextDecision = nextNode.unwrapped as? DecisionNode else {
            return nil
        }
        
        return nextDecision
    }
    
    /// Collects all decision results starting from a root decision, following precedes edges
    @MainActor
    public func collectDecisionResults(startingFrom rootID: NodeID) -> [String: PreferenceValue] {
        var results: [String: PreferenceValue] = [:]
        var currentID: NodeID? = rootID
        var visited: Set<NodeID> = []
        
        while let decisionID = currentID, !visited.contains(decisionID) {
            visited.insert(decisionID)
            
            guard let decisionNode = nodes.first(where: { $0.id == decisionID }),
                  let decision = decisionNode.unwrapped as? DecisionNode else {
                break
            }
            
            // Collect this decision's result
            if decision.inputType == .numeric {
                if let value = decision.numericValue {
                    results[decision.preferenceKey] = .number(value)
                }
            } else if decision.inputType == .singleChoice {
                if let selectedID = decision.selectedChoiceID,
                   let choiceNode = nodes.first(where: { $0.id == selectedID }),
                   let choice = choiceNode.unwrapped as? ChoiceNode {
                    results[decision.preferenceKey] = choice.value
                }
            } else if decision.inputType == .multiChoice {
                let selectedValues = decision.selectedChoiceIDs.compactMap { choiceID -> String? in
                    guard let choiceNode = nodes.first(where: { $0.id == choiceID }),
                          let choice = choiceNode.unwrapped as? ChoiceNode,
                          case .string(let str) = choice.value else {
                        return nil
                    }
                    return str
                }
                if !selectedValues.isEmpty {
                    results[decision.preferenceKey] = .stringArray(selectedValues)
                }
            }
            
            // Move to next decision
            currentID = getNextDecision(after: decisionID)?.id
        }
        
        return results
    }
    
    // MARK: - Preference Node Operations
    
    /// Creates a preference node from collected decision results
    @MainActor
    public func createPreference(
        name: String,
        guestCount: Int,
        dinnerTime: Date,
        preferences: [String: PreferenceValue],
        mealNodeID: NodeID? = nil,
        baseRecipeID: NodeID? = nil,
        at position: CGPoint
    ) async -> PreferenceNode {
        let preference = PreferenceNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            guestCount: guestCount,
            dinnerTime: dinnerTime,
            mealNodeID: mealNodeID,
            baseRecipeID: baseRecipeID,
            preferences: preferences
        )
        
        nodes.append(AnyNode(preference))
        nextNodeLabel += 1
        
        // Link to meal if specified
        if let mealID = mealNodeID {
            await addEdge(from: preference.id, target: mealID, type: .configures)
        }
        
        return preference
    }
    
    /// Generates a preference node from a decision tree
    @MainActor
    public func generatePreference(
        from rootDecisionID: NodeID,
        name: String,
        guestCount: Int,
        dinnerTime: Date,
        mealNodeID: NodeID? = nil,
        baseRecipeID: NodeID? = nil,
        at position: CGPoint
    ) async -> PreferenceNode {
        let collectedPrefs = collectDecisionResults(startingFrom: rootDecisionID)
        
        let preference = await createPreference(
            name: name,
            guestCount: guestCount,
            dinnerTime: dinnerTime,
            preferences: collectedPrefs,
            mealNodeID: mealNodeID,
            baseRecipeID: baseRecipeID,
            at: position
        )
        
        // Link preference to root decision for tracking
        await addEdge(from: preference.id, target: rootDecisionID, type: .decidedBy)
        
        return preference
    }
    
    /// Updates a PreferenceNode with a cloned recipe ID
    @MainActor
    public func updatePreferenceWithClonedRecipe(
        preferenceID: NodeID,
        clonedRecipeID: NodeID
    ) -> Bool {
        guard let prefIndex = nodes.firstIndex(where: { $0.id == preferenceID }),
              let preference = nodes[prefIndex].unwrapped as? PreferenceNode else {
            return false
        }
        
        // Create updated preference with clonedRecipeID
        let updatedPreference = PreferenceNode(
            id: preference.id,
            label: preference.label,
            position: preference.position,
            velocity: preference.velocity,
            radius: preference.radius,
            name: preference.name,
            guestCount: preference.guestCount,
            dinnerTime: preference.dinnerTime,
            createdAt: preference.createdAt,
            mealNodeID: preference.mealNodeID,
            baseRecipeID: preference.baseRecipeID,
            clonedRecipeID: clonedRecipeID,
            preferences: preference.preferences
        )
        
        nodes[prefIndex] = AnyNode(updatedPreference)
        return true
    }
    
    /// Applies a PersonNode's default preferences to a decision tree
    /// This pre-fills decisions based on person's spice level and dietary restrictions
    @MainActor
    // swiftlint:disable:next cyclomatic_complexity
    public func applyPersonDefaults(
        personID: NodeID,
        toDecisionTree rootDecisionID: NodeID
    ) async -> Bool {
        // Get the person node
        guard let personNode = nodes.first(where: { $0.id == personID }),
              let person = personNode.unwrapped as? PersonNode else {
            return false
        }
        
        // Traverse decision tree and apply defaults
        var currentID: NodeID? = rootDecisionID
        var visited: Set<NodeID> = []
        var appliedCount = 0
        
        while let decisionID = currentID, !visited.contains(decisionID) {
            visited.insert(decisionID)
            
            guard let decisionNode = nodes.first(where: { $0.id == decisionID }),
                  let decision = decisionNode.unwrapped as? DecisionNode else {
                break
            }
            
            // Apply defaults based on preference key
            switch decision.preferenceKey.lowercased() {
            case "spicelevel", "spice_level", "spice":
                if let spiceLevel = person.defaultSpiceLevel,
                   decision.inputType == .singleChoice {
                    // Find matching choice
                    let childIDs = edges
                        .filter { $0.from == decisionID && $0.type == .hierarchy }
                        .map { $0.target }
                    
                    for childID in childIDs {
                        if let choiceNode = nodes.first(where: { $0.id == childID }),
                           let choice = choiceNode.unwrapped as? ChoiceNode,
                           choice.choiceText.lowercased() == spiceLevel.lowercased() {
                            _ = await selectChoice(childID, in: decisionID)
                            appliedCount += 1
                            break
                        }
                    }
                }
                
            case "dietary", "dietary_restrictions", "restrictions":
                if !person.dietaryRestrictions.isEmpty,
                   decision.inputType == .multiChoice {
                    // Apply dietary restrictions as multi-select
                    let childIDs = edges
                        .filter { $0.from == decisionID && $0.type == .hierarchy }
                        .map { $0.target }
                    
                    for childID in childIDs {
                        if let choiceNode = nodes.first(where: { $0.id == childID }),
                           let choice = choiceNode.unwrapped as? ChoiceNode {
                            let choiceTextLower = choice.choiceText.lowercased()
                            let shouldSelect = person.dietaryRestrictions.contains { restriction in
                                choiceTextLower.contains(restriction.lowercased()) ||
                                restriction.lowercased().contains(choiceTextLower)
                            }
                            
                            if shouldSelect {
                                _ = await selectChoice(childID, in: decisionID)
                                appliedCount += 1
                            }
                        }
                    }
                }
                
            default:
                // No default for this preference key
                break
            }
            
            // Move to next decision
            currentID = getNextDecision(after: decisionID)?.id
        }
        
        return appliedCount > 0
    }
}
