//
//  AttractionCalculator.swift
//  GraphEditorShared
//
//  Created by handcart on 8/12/25.
//

import Foundation
import CoreGraphics

struct AttractionCalculator {
    let symmetricFactor: CGFloat

    init(symmetricFactor: CGFloat) {
        self.symmetricFactor = symmetricFactor
    }

    func applyAttractions(forces: [NodeID: CGPoint], edges: [GraphEdge], nodes: [any NodeProtocol]) -> [NodeID: CGPoint] {
        var updatedForces = forces
        for edge in edges {
            guard let fromNode = nodes.first(where: { $0.id == edge.from }),
                  let toNode = nodes.first(where: { $0.id == edge.to }) else { continue }
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
            
            let currentForceFrom = updatedForces[fromNode.id] ?? .zero
            updatedForces[fromNode.id] = CGPoint(x: currentForceFrom.x + symForceX, y: currentForceFrom.y + symForceY)
            
            let currentForceTo = updatedForces[toNode.id] ?? .zero
            let isAsymmetric = edge.type == .hierarchy  // Asymmetric for .hierarchy
            if isAsymmetric {
                // Stronger pull for 'to' (child) toward 'from' (parent); add vertical bias
                let asymmetricFactor: CGFloat = 1.5  // Tune: Stronger for hierarchy
                var asymmetricForceY = forceY * asymmetricFactor
                asymmetricForceY += Constants.Physics.verticalBias  // Pull downward (assume positive Y down; adjust if not)
                updatedForces[toNode.id] = CGPoint(x: currentForceTo.x - forceX * asymmetricFactor, y: currentForceTo.y - asymmetricForceY)
            } else {
                // Symmetric for .association
                updatedForces[toNode.id] = CGPoint(x: currentForceTo.x - forceX + symForceX, y: currentForceTo.y - forceY + symForceY)
            }
        }
        return updatedForces
    }
}
