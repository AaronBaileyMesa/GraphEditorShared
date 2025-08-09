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
        public static let repulsion: CGFloat = 1500  // Reduced from 3000 for faster damping, less spread
        public static let damping: CGFloat = 0.92  // Increased from 0.85 for quicker stability
        public static let idealLength: CGFloat = 70
        public static let centeringForce: CGFloat = 0.04  // Slight increase for better pull without oscillation
        public static let distanceEpsilon: CGFloat = 1e-3
        public static let timeStep: CGFloat = 0.03  // Reduced from 0.05 for finer integration
        public static let velocityThreshold: CGFloat = 0.3  // Increased from 0.2 for leniency in tests
        public static let maxSimulationSteps = 5000  // Increased from 3000
        public static let minQuadSize: CGFloat = 1e-6
        public static let maxQuadtreeDepth = 20  // Already reduced
        public static let maxNodesForQuadtree = 200
    }
    
    public enum App {
        public static let nodeModelRadius: CGFloat = 10.0
        public static let hitScreenRadius: CGFloat = 20.0  // Buffer for hit detection
        public static let tapThreshold: CGFloat = 10.0  // Pixels for tap vs. drag distinction
        public static let numZoomLevels: Int = 20  // For crown mapping
    }
    
    // Add more enums as needed (e.g., UI, Testing)
}
