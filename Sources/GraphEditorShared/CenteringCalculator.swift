//
//  CenteringCalculator.swift
//  GraphEditorShared
//
//  Created by handcart on 8/12/25.
//

import Foundation
import CoreGraphics

struct CenteringCalculator {
    let simulationBounds: CGSize

    @available(iOS 16.0, *)
    func applyCentering(forces: [NodeID: CGPoint], nodes: [any NodeProtocol], layoutMode: LayoutMode) -> [NodeID: CGPoint] {
        var updatedForces = forces
        
        // For hierarchy mode, apply gentle upward-left gravity instead of strong centering
        if layoutMode == .hierarchy {
            // Gentle gravity toward upper-left quadrant
            let targetPoint = CGPoint(x: simulationBounds.width * 0.3, y: simulationBounds.height * 0.3)
            let reducedForce = Constants.Physics.centeringForce * 0.3  // Much weaker than network mode
            
            for node in nodes {
                let deltaX = targetPoint.x - node.position.x
                let deltaY = targetPoint.y - node.position.y
                let distToTarget = hypot(deltaX, deltaY)
                let forceX = deltaX * reducedForce * (1 + distToTarget / max(simulationBounds.width, simulationBounds.height))
                let forceY = deltaY * reducedForce * (1 + distToTarget / max(simulationBounds.width, simulationBounds.height))
                let currentForce = updatedForces[node.id] ?? .zero
                updatedForces[node.id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
            }
        } else {
            // Network mode: standard centering to middle
            let center = CGPoint(x: simulationBounds.width / 2, y: simulationBounds.height / 2)
            for node in nodes {
                let deltaX = center.x - node.position.x
                let deltaY = center.y - node.position.y
                let distToCenter = hypot(deltaX, deltaY)
                let forceX = deltaX * Constants.Physics.centeringForce * (1 + distToCenter / max(simulationBounds.width, simulationBounds.height))
                let forceY = deltaY * Constants.Physics.centeringForce * (1 + distToCenter / max(simulationBounds.width, simulationBounds.height))
                let currentForce = updatedForces[node.id] ?? .zero
                updatedForces[node.id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
            }
        }
        return updatedForces
    }
}
