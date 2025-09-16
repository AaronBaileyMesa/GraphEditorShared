//
//  AttractionCalculator.swift
//  GraphEditorShared
//
//  Created by handcart on 8/12/25.
//

import Foundation  // For hypot, CGFloat, etc.
import CoreGraphics  // For CGPoint, CGVector (used internally)

struct AttractionCalculator {
    let symmetricFactor: CGFloat
    let useAsymmetric: Bool  // New: Controls full asymmetry for hierarchy edges

    init(symmetricFactor: CGFloat, useAsymmetric: Bool = false) {  // Default false to preserve existing behavior
        self.symmetricFactor = symmetricFactor
        self.useAsymmetric = useAsymmetric
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
                // Existing hierarchy logic (preserved when flag false)
                let asymmetricFactor: CGFloat = 1.5  // Your original
                var asymmetricForceY = forceY * asymmetricFactor
                asymmetricForceY += Constants.Physics.verticalBias  // Your vertical pull
                updatedForces[toNode.id] = CGPoint(x: currentForceTo.x - forceX * asymmetricFactor, y: currentForceTo.y - asymmetricForceY)
                updatedForces[fromNode.id] = CGPoint(x: currentForceFrom.x + symForceX, y: currentForceFrom.y + symForceY)
            } else {
                // Symmetric for .association (unchanged)
                updatedForces[toNode.id] = CGPoint(x: currentForceTo.x - forceX + symForceX, y: currentForceTo.y - forceY + symForceY)
                updatedForces[fromNode.id] = CGPoint(x: currentForceFrom.x + symForceX, y: currentForceFrom.y + symForceY)
            }
        }
        return updatedForces
    }
}
