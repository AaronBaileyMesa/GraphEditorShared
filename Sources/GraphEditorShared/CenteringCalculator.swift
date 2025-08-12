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

    init(simulationBounds: CGSize) {
        self.simulationBounds = simulationBounds
    }

    func applyCentering(forces: [NodeID: CGPoint], nodes: [any NodeProtocol]) -> [NodeID: CGPoint] {
        var updatedForces = forces
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
        return updatedForces
    }
}
