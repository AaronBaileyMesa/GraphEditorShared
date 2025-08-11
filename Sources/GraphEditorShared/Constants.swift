//
//  Constants.swift
//  GraphEditorShared
//
//  Created by handcart on 8/6/25.
//


// Sources/GraphEditorShared/Constants.swift

import CoreGraphics

public enum Constants {
    public enum Physics {
        public static let stiffness: CGFloat = 0.8
        public static let repulsion: CGFloat = 2200  // Reduced for less spread/oscillation
        public static let damping: CGFloat = 0.96    // Increased for faster stability
        public static let idealLength: CGFloat = 70
        public static let centeringForce: CGFloat = 0.06  // Increased for tighter layouts on small screens
        public static let distanceEpsilon: CGFloat = 1e-3
        public static let timeStep: CGFloat = 0.03
        public static let velocityThreshold: CGFloat = 0.1  // Tightened for better convergence (runs longer to lower velocities)
        public static let maxSimulationSteps = 5000
        public static let minQuadSize: CGFloat = 1e-6
        public static let maxQuadtreeDepth = 20
        public static let maxNodesForQuadtree = 200
    }
    
    public enum App {
        public static let nodeModelRadius: CGFloat = 10.0
        public static let hitScreenRadius: CGFloat = 40.0  // Larger for watchOS tap targets
        public static let tapThreshold: CGFloat = 10.0  // Pixels for tap vs. drag distinction
        public static let numZoomLevels: Int = 20  // For crown mapping
    }
    
    // Add more enums as needed (e.g., UI, Testing)
}
