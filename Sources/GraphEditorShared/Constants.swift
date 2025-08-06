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
        public static let stiffness: CGFloat = 0.5
        public static let repulsion: CGFloat = 5000
        public static let damping: CGFloat = 0.85
        public static let idealLength: CGFloat = 100
        public static let centeringForce: CGFloat = 0.005
        public static let distanceEpsilon: CGFloat = 1e-3
        public static let timeStep: CGFloat = 0.05
        public static let velocityThreshold: CGFloat = 0.2
        public static let maxSimulationSteps = 500
        public static let minQuadSize: CGFloat = 1e-6
        public static let maxQuadtreeDepth = 64
        public static let maxNodesForQuadtree = 200  // Adjust based on device profiling
    }
    
    public enum App {
        public static let nodeModelRadius: CGFloat = 10.0
        public static let hitScreenRadius: CGFloat = 20.0  // Buffer for hit detection
        public static let tapThreshold: CGFloat = 10.0  // Pixels for tap vs. drag distinction
        public static let numZoomLevels: Int = 20  // For crown mapping
    }
    
    // Add more enums as needed (e.g., UI, Testing)
}