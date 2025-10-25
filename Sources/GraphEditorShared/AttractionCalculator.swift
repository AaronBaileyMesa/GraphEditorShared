//
//  AttractionCalculator.swift
//  GraphEditorShared
//
//  Created by handcart on 8/12/25.
//

import Foundation  // For hypot, CGFloat, etc.
import CoreGraphics  // For CGPoint, CGVector (used internally)

@available(iOS 16.0, watchOS 9.0, *)
struct AttractionCalculator {
    let symmetricFactor: CGFloat
    let useAsymmetric: Bool  // New: Controls full asymmetry for hierarchy edges
    let usePreferredAngles: Bool  // NEW: Controls angular torque for hierarchies

    init(symmetricFactor: CGFloat, useAsymmetric: Bool = false, usePreferredAngles: Bool = false) {  // UPDATED: Added param, default false
        self.symmetricFactor = symmetricFactor
        self.useAsymmetric = useAsymmetric
        self.usePreferredAngles = usePreferredAngles
    }

    func applyAttractions(forces: [NodeID: CGPoint], edges: [GraphEdge], nodes: [any NodeProtocol]) -> [NodeID: CGPoint] {
        var updatedForces = forces
        for edge in edges {
            guard let fromNode = nodes.first(where: { $0.id == edge.from }),
                  let toNode = nodes.first(where: { $0.id == edge.target }) else { continue }
            let deltaX = toNode.position.x - fromNode.position.x
            let deltaY = toNode.position.y - fromNode.position.y
            let dist = max(hypot(deltaX, deltaY), Constants.Physics.distanceEpsilon)
            let forceMagnitude = Constants.Physics.stiffness * (dist - Constants.Physics.idealLength)
            let forceDirectionX = deltaX / dist
            let forceDirectionY = deltaY / dist
            let forceX = forceDirectionX * forceMagnitude
            let forceY = forceDirectionY * forceMagnitude
            
            let symForceX = forceX * self.symmetricFactor
            let symForceY = forceY * self.symmetricFactor
            
            let currentForceFrom = updatedForces[fromNode.id] ?? CGPoint.zero
            let currentForceTo = updatedForces[toNode.id] ?? CGPoint.zero
            
            let isHierarchy = edge.type == .hierarchy
            if isHierarchy && self.useAsymmetric {
                // Full asymmetric: Strong pull 'to' toward 'from'; minimal back-pull on 'from' (test-friendly)
                let asymmetricFactor: CGFloat = 2.0  // Stronger pull for 'to'; tune if needed
                let toForceX = -forceX * asymmetricFactor  // Pull 'to' left/up toward 'from'
                let toForceY = -forceY * asymmetricFactor
                let fromBackPullX = forceX * 0.1  // Minimal back-pull (10% to keep stable)
                let fromBackPullY = forceY * 0.1
                
                updatedForces[toNode.id] = CGPoint(x: currentForceTo.x + toForceX, y: currentForceTo.y + toForceY)
                updatedForces[fromNode.id] = CGPoint(x: currentForceFrom.x + fromBackPullX, y: currentForceFrom.y + fromBackPullY)
            } else if isHierarchy {
                // Symmetric for stability (net force zero)
                updatedForces[toNode.id] = CGPoint(x: currentForceTo.x - forceX + symForceX, y: currentForceTo.y - forceY + symForceY)
                updatedForces[fromNode.id] = CGPoint(x: currentForceFrom.x + symForceX, y: currentForceFrom.y + symForceY)
            } else {
                // Symmetric for .association (unchanged)
                updatedForces[toNode.id] = CGPoint(x: currentForceTo.x - forceX + symForceX, y: currentForceTo.y - forceY + symForceY)
                updatedForces[fromNode.id] = CGPoint(x: currentForceFrom.x + symForceX, y: currentForceFrom.y + symForceY)
            }
            
            // NEW: Apply preferred angle torque if enabled and hierarchy
            if isHierarchy && usePreferredAngles, let parent = fromNode as? ToggleNode {
                let siblingIndex = parent.childOrder.firstIndex(of: toNode.id) ?? 0
                let siblingCount = max(parent.childOrder.count, 1)
                let baseAngle: CGFloat = .pi * 1.5  // 270° downward
                let spread: CGFloat = .pi / 1.5  // ~120° fan for spacing
                let anglePerSibling = spread / CGFloat(siblingCount - 1)
                let preferredAngle = baseAngle - spread / 2 + CGFloat(siblingIndex) * anglePerSibling
                
                let actualAngle = atan2(deltaY, deltaX)
                let angleDiff = (actualAngle - preferredAngle).clamped(to: -.pi ... .pi)  // Shortest angular distance
                let torqueMagnitude = Constants.Physics.angularStiffness * angleDiff * forceMagnitude  // Scale by distance force
                
                // Torque as perpendicular components
                let torqueX = -torqueMagnitude * forceDirectionY
                let torqueY = torqueMagnitude * forceDirectionX
                
                // Apply to child (asymmetric guidance)
                let currentTo = updatedForces[toNode.id] ?? .zero
                updatedForces[toNode.id] = CGPoint(x: currentTo.x + torqueX, y: currentTo.y + torqueY)
            }
        }
        return updatedForces
    }
}
