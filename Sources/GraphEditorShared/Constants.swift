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
        public static let stiffness: CGFloat = 0.8  // Balanced (slightly higher than original for tighter edges)
        public static let repulsion: CGFloat = 4000  // Compromise (lower than original 5000 for less spreading, higher than 3000 to match test forces)
        public static let damping: CGFloat = 0.85  // Reverted to original for faster convergence (reduces velocity quicker than 0.95)
        public static let idealLength: CGFloat = 90  // Slight decrease for watch screen compactness
        public static let centeringForce: CGFloat = 0.015  // Mild increase for better centering without oscillation
        public static let distanceEpsilon: CGFloat = 1e-3
        public static let timeStep: CGFloat = 0.05
        public static let velocityThreshold: CGFloat = 0.2  // Reverted to original (matches test expectation for stop condition)
        public static let maxSimulationSteps = 500
        public static let minQuadSize: CGFloat = 1e-6
        public static let maxQuadtreeDepth = 64
        public static let maxNodesForQuadtree = 200  // Unchanged
    }
    
    public enum App {
        public static let nodeModelRadius: CGFloat = 10.0
        public static let hitScreenRadius: CGFloat = 20.0  // Buffer for hit detection
        public static let tapThreshold: CGFloat = 10.0  // Pixels for tap vs. drag distinction
        public static let numZoomLevels: Int = 20  // For crown mapping
    }
    
    // Add more enums as needed (e.g., UI, Testing)
}
