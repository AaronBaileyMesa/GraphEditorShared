//
//  GraphError.swift
//  GraphEditorShared
//
//  Created by handcart on 10/13/25.
//

import Foundation  // Added for LocalizedError

public enum GraphError: Error, LocalizedError {
    case storageFailure(String)
    case simulationTimeout(Int)
    case invalidState(String)
    case graphNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .storageFailure(let msg): return "Storage error: \(msg)"
        case .simulationTimeout(let steps): return "Simulation timed out after \(steps) steps"
        case .invalidState(let msg): return "Invalid state: \(msg)"
        case .graphNotFound(let name): return "Graph '\(name)' not found"
        }
    }
}
