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
        public static let stiffness: CGFloat = 0.4  // Reduced from 0.8 for softer springs
        public static let repulsion: CGFloat = 1200  // Reduced from 2200 for less aggressive push
        public static let damping: CGFloat = 0.9  // Reduced from 0.99 for faster settling
        public static let idealLength: CGFloat = 80  // Slightly increased for more space
        public static let centeringForce: CGFloat = 0.03  // Reduced from 0.06 to avoid over-pull
        public static let distanceEpsilon: CGFloat = 1e-3
        public static let timeStep: CGFloat = 0.02  // Slightly reduced for finer steps
        public static let velocityThreshold: CGFloat = 0.3  // Increased from 0.2 for earlier stop
        public static let maxSimulationSteps = 500  // Further reduced from 1000 for quick convergence
        public static let minQuadSize: CGFloat = 1e-6
        public static let maxQuadtreeDepth = 20
        public static let maxNodesForQuadtree = 200
        public static let minCollisionDist: CGFloat = 35.0  // New: For anti-collision separation
        public static let verticalBias: CGFloat = 0.0  // New: Downward bias for hierarchy edges (tune as needed)
    }
    
    public enum App {
        public static let nodeModelRadius: CGFloat = 10.0
        public static let hitScreenRadius: CGFloat = 50.0  // Larger for watchOS tap targets
        public static let tapThreshold: CGFloat = 20.0  // Tightened from 10.0 for small screens
        public static let numZoomLevels: Int = 20  // For crown mapping
        public static let contentPadding: CGFloat = 50.0  // Padding for graph bounds
        public static let maxZoom: CGFloat = 8.0  // Maximum zoom level
    }
    
    // Add more enums as needed (e.g., UI, Testing)
}
