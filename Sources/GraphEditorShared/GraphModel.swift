//
//  GraphModel.swift
//  GraphEditorShared
//
//  Created by handcart on 10/3/25.
//

import os.log
import SwiftUI
import Combine
import Foundation

#if os(watchOS)
import WatchKit
#endif

@available(iOS 16.0, watchOS 6.0, *)
@MainActor public class GraphModel: ObservableObject {
    @Published public var currentGraphName: String = "default"  // Standardized to "default" for consistency
    @Published public var nodes: [AnyNode] = []
    @Published public var edges: [GraphEdge] = []
    @Published public var isSimulating: Bool = false
    @Published public var isStable: Bool = false
    @Published public var simulationError: Error?
    @Published public var mode: GraphMode = .network  // Per-graph mode
    public let changesPublisher = PassthroughSubject<Void, Never>()  // For future real-time sync

    private static let logger = Logger.forCategory("graphmodel-storage")

    var simulationTimer: Timer?
    var undoStack: [UndoGraphState] = []
    var redoStack: [UndoGraphState] = []
    public var maxUndo: Int = 10

    public var nextNodeLabel = 1

    public let storage: GraphStorage
    public var physicsEngine: PhysicsEngine

    public var hiddenNodeIDs: Set<NodeID> {
        // Removed debug print to avoid side effects; add os_log if needed for production logging.
        var hidden = Set<NodeID>()
        var toHide: [NodeID] = []

        for node in nodes where node.unwrapped.shouldHideChildren() {
            let children = edges.filter { $0.from == node.id && $0.type == .hierarchy }.map { $0.target }
            toHide.append(contentsOf: children)
        }

        let adj = buildAdjacencyList(for: .hierarchy)
        while !toHide.isEmpty {
            let current = toHide.removeLast()
            if hidden.insert(current).inserted {
                let children = adj[current] ?? []
                toHide.append(contentsOf: children)
            }
        }

        return hidden
    }

    lazy var simulator: GraphSimulator = {
        GraphSimulator(
            getNodes: { [weak self] in
                await MainActor.run {
                    self?.nodes.map { $0.unwrapped } ?? []
                }
            },
            setNodes: { [weak self] newNodes in
                await MainActor.run {
                    self?.nodes = newNodes.map { AnyNode($0) }
                }
            },
            getEdges: { [weak self] in
                await MainActor.run {
                    self?.edges ?? []
                }
            },
            getVisibleNodes: { [weak self] in
                await MainActor.run {
                    self?.visibleNodes() ?? []
                }
            },
            getVisibleEdges: { [weak self] in
                await MainActor.run {
                    self?.visibleEdges() ?? []
                }
            },
            physicsEngine: self.physicsEngine,
            onStable: { [weak self] in
                guard let self = self, !self.isStable else { return }
                let velocities = self.nodes.map { hypot($0.velocity.x, $0.velocity.y) }
                if velocities.allSatisfy({ $0 < 0.001 }) {
                    // CHANGED: Qualified static logger
                    Self.logger.infoLog("Simulation stable: Centering nodes")  // Replaced print
                    let centeredNodes = self.physicsEngine.centerNodes(nodes: self.nodes.map { $0.unwrapped })
                    self.nodes = centeredNodes.map { AnyNode($0.with(position: $0.position, velocity: .zero)) }
                    self.isStable = true
                    Task.detached {
                        await self.stopSimulation()
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await MainActor.run {
                            self.isStable = false
                        }
                    }
                    self.objectWillChange.send()
                }
            }
        )
    }()
    
    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    public var canRedo: Bool {
        !redoStack.isEmpty
    }

    public init(storage: GraphStorage, physicsEngine: PhysicsEngine) {
        self.storage = storage
        self.physicsEngine = physicsEngine
        // CHANGED: Qualified static logger
        Self.logger.infoLog("GraphModel initialized with storage: \(type(of: storage))")  // Existing, already good
    }
    
    func buildAdjacencyList(for type: EdgeType) -> [NodeID: [NodeID]] {
        var adj: [NodeID: [NodeID]] = [:]
        for edge in edges where edge.type == type {
            adj[edge.from, default: []].append(edge.target)
        }
        return adj
    }
}
