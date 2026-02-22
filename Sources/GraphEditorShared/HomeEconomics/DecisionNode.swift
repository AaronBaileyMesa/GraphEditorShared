//
//  DecisionNode.swift
//  GraphEditorShared
//
//  Represents a decision point in a decision tree with choice children
//

import SwiftUI
import Foundation

/// Input type for a decision
public enum DecisionInputType: String, Codable, CaseIterable {
    case singleChoice  // Pick one child ChoiceNode
    case multiChoice   // Pick multiple ChoiceNodes
    case numeric       // Crown input, no children needed
}

/// Represents a decision point in a decision tree
@available(iOS 16.0, watchOS 9.0, *)
public struct DecisionNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // ChoiceNode children
    public var childOrder: [NodeID]
    
    // Decision-specific properties
    public let question: String  // "What protein?"
    public let preferenceKey: String  // "protein" -> maps to PreferenceNode
    public let inputType: DecisionInputType
    public var selectedChoiceID: NodeID?  // Which choice was picked (for singleChoice)
    public var selectedChoiceIDs: [NodeID]  // Which choices were picked (for multiChoice)
    public var numericValue: Double?  // For numeric input type
    
    public var displayRadius: CGFloat {
        radius
    }
    
    public var fillColor: Color {
        if inputType == .numeric {
            return numericValue != nil ? .green : .yellow
        } else if inputType == .multiChoice {
            return selectedChoiceIDs.isEmpty ? .yellow : .green
        } else {
            return selectedChoiceID != nil ? .green : .yellow
        }
    }
    
    public var contents: [NodeContent] {
        get {
            [.string(question)]
        }
        set {
            _ = newValue  // Read-only
        }
    }
    
    // MARK: - Initializers
    
    public init(
        id: NodeID = UUID(),
        label: Int,
        position: CGPoint,
        velocity: CGPoint = .zero,
        radius: CGFloat = 18.0,
        question: String,
        preferenceKey: String,
        inputType: DecisionInputType,
        selectedChoiceID: NodeID? = nil,
        selectedChoiceIDs: [NodeID] = [],
        numericValue: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
        self.radius = radius
        self.isExpanded = true
        self.isCollapsible = true
        self.children = []
        self.childOrder = []
        self.question = question
        self.preferenceKey = preferenceKey
        self.inputType = inputType
        self.selectedChoiceID = selectedChoiceID
        self.selectedChoiceIDs = selectedChoiceIDs
        self.numericValue = numericValue
    }
    
    // MARK: - NodeProtocol Methods
    
    public func with(position: CGPoint, velocity: CGPoint) -> DecisionNode {
        DecisionNode(
            id: id,
            label: label,
            position: position,
            velocity: velocity,
            radius: radius,
            question: question,
            preferenceKey: preferenceKey,
            inputType: inputType,
            selectedChoiceID: selectedChoiceID,
            selectedChoiceIDs: selectedChoiceIDs,
            numericValue: numericValue
        )
    }
    
    public func with(position: CGPoint, velocity: CGPoint, contents: [NodeContent]) -> DecisionNode {
        with(position: position, velocity: velocity)
    }
    
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        AnyView(
            Circle()
                .fill(fillColor)
                .frame(width: displayRadius * 2 * zoomScale, height: displayRadius * 2 * zoomScale)
                .overlay(
                    Text("\(label)")
                        .font(.system(size: 12 * zoomScale))
                        .foregroundColor(.white)
                )
        )
    }
    
    public func handlingTap() -> DecisionNode {
        self
    }
    
    public func shouldHideChildren() -> Bool {
        !isExpanded
    }
    
    public mutating func collapse() {
        isExpanded = false
    }
    
    public mutating func bulkCollapse() {
        isExpanded = false
    }

    public var typeDescriptor: NodeTypeDescriptor {
        DecisionNodeDescriptor(node: self)
    }

    public var mass: CGFloat {
        12.0
    }
    
    public var isVisible: Bool {
        true
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, label, positionX, positionY, velocityX, velocityY, radius
        case isExpanded, isCollapsible, children, childOrder
        case question, preferenceKey, inputType
        case selectedChoiceID, selectedChoiceIDs, numericValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(NodeID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
        
        // swiftlint:disable:next identifier_name
        let x = try container.decode(CGFloat.self, forKey: .positionX)
        // swiftlint:disable:next identifier_name
        let y = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: x, y: y)

        // swiftlint:disable:next identifier_name
        let vx = try container.decode(CGFloat.self, forKey: .velocityX)
        // swiftlint:disable:next identifier_name
        let vy = try container.decode(CGFloat.self, forKey: .velocityY)
        velocity = CGPoint(x: vx, y: vy)
        
        radius = try container.decode(CGFloat.self, forKey: .radius)
        isExpanded = try container.decode(Bool.self, forKey: .isExpanded)
        isCollapsible = try container.decode(Bool.self, forKey: .isCollapsible)
        children = try container.decode([NodeID].self, forKey: .children)
        childOrder = try container.decode([NodeID].self, forKey: .childOrder)
        
        question = try container.decode(String.self, forKey: .question)
        preferenceKey = try container.decode(String.self, forKey: .preferenceKey)
        inputType = try container.decode(DecisionInputType.self, forKey: .inputType)
        selectedChoiceID = try container.decodeIfPresent(NodeID.self, forKey: .selectedChoiceID)
        selectedChoiceIDs = try container.decode([NodeID].self, forKey: .selectedChoiceIDs)
        numericValue = try container.decodeIfPresent(Double.self, forKey: .numericValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
        try container.encode(radius, forKey: .radius)
        try container.encode(isExpanded, forKey: .isExpanded)
        try container.encode(isCollapsible, forKey: .isCollapsible)
        try container.encode(children, forKey: .children)
        try container.encode(childOrder, forKey: .childOrder)
        
        try container.encode(question, forKey: .question)
        try container.encode(preferenceKey, forKey: .preferenceKey)
        try container.encode(inputType, forKey: .inputType)
        try container.encodeIfPresent(selectedChoiceID, forKey: .selectedChoiceID)
        try container.encode(selectedChoiceIDs, forKey: .selectedChoiceIDs)
        try container.encodeIfPresent(numericValue, forKey: .numericValue)
    }
}
