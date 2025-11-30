//
//  GraphModel+ControlNodes.swift
//  GraphEditorShared
//
//  Created by handcart on 2025-11-25
//  Description: Extension for ephemeral ControlNode management, config persistence, and actions.
//               Integrates with core GraphModel for context-dependent UI controls.
//

import SwiftUI
import Combine
import Foundation
import os

#if os(watchOS)
import WatchKit
#endif

@available(iOS 16.0, watchOS 6.0, *)
extension GraphModel {
    // MARK: - Ephemeral Management
    @MainActor
    public func updateEphemerals(selectedNodeID: NodeID?) {
        ephemeralControlNodes.removeAll()
        ephemeralControlEdges.removeAll()
        
        // Global controls
        addGlobalControls()
        
        // Per-node controls
        if let ownerID = selectedNodeID {
            addControlsForNode(ownerID)
        }
        
        objectWillChange.send()
        changesPublisher.send()
    }
    
    private func addGlobalControls() {
        let centroid = self.centroid ?? .zero
        var globalKinds: [ControlKind] = []
        
        if canUndo { globalKinds.append(.undo) }
        if canRedo { globalKinds.append(.redo) }
        globalKinds.append(.configMode)  // Always show config entry
        
        let filtered = globalKinds.filter { kind in
            globalUiConfig.first(where: { $0.kind == kind })?.isVisible ?? true
        }
        
        let sortedFiltered = filtered.sorted { kind1, kind2 in
            let priority1 = globalUiConfig.first(where: { $0.kind == kind1 })?.priority ?? 0
            let priority2 = globalUiConfig.first(where: { $0.kind == kind2 })?.priority ?? 0
            return priority1 > priority2
        }
        
        let clusterRadius: CGFloat = 20.0
        let angleStep = CGFloat.pi * 2 / CGFloat(max(sortedFiltered.count, 1))
        
        for (index, kind) in sortedFiltered.enumerated() {
            let angle = CGFloat(index) * angleStep
            let offset = CGPoint(x: cos(angle) * clusterRadius, y: sin(angle) * clusterRadius)
            let position = centroid + offset
            
            let config = globalUiConfig.first(where: { $0.kind == kind }) ?? ControlConfig(kind: kind)
            
            var control = ControlNode(
                position: position,
                ownerID: nil,  // Global → no owner
                kind: kind,
                isVisible: config.isVisible,
                priority: config.priority
            )

            control.action = { [weak self, kind] in
                Task { @MainActor in
                    await self?.handleControlAction(kind: kind, ownerID: nil)
                }
            }
            
            ephemeralControlNodes.append(control)
        }
    }
    
    private func addControlsForNode(_ ownerID: NodeID) {
        guard let ownerNode = nodes.first(where: { $0.id == ownerID }) else { return }
        let ownerPos = ownerNode.position
        let ownerRadius = ownerNode.displayRadius
        
        // New per-node controls
        let nodeKinds: [ControlKind] = [.addChild, .deleteNode, .toggleExpansion]
        
        let filtered = nodeKinds.filter { kind in
            uiConfig[ownerID]?.first(where: { $0.kind == kind })?.isVisible ?? true
        }
        
        let sortedFiltered = filtered.sorted { kind1, kind2 in
            let priority1 = uiConfig[ownerID]?.first(where: { $0.kind == kind1 })?.priority ?? 0
            let priority2 = uiConfig[ownerID]?.first(where: { $0.kind == kind2 })?.priority ?? 0
            return priority1 > priority2
        }
        
        let clusterRadius = ownerRadius + 30.0
        let angleStep = CGFloat.pi * 2 / CGFloat(max(sortedFiltered.count, 1))
        
        for (index, kind) in sortedFiltered.enumerated() {
            let angle = CGFloat(index) * angleStep
            let offset = CGPoint(x: cos(angle) * clusterRadius, y: sin(angle) * clusterRadius)
            let position = ownerPos + offset
            
            let config = uiConfig[ownerID]?.first(where: { $0.kind == kind }) ?? ControlConfig(kind: kind)
            
            var control = ControlNode(
                position: position,
                ownerID: ownerID,  // Per-node → has owner
                kind: kind,
                isVisible: config.isVisible,
                priority: config.priority
            )
            
            control.action = { [weak self, kind, ownerID] in
                Task { @MainActor in
                    await self?.handleControlAction(kind: kind, ownerID: ownerID)
                }
            }
            
            ephemeralControlNodes.append(control)
            
            // Optional visual connection
            let edge = GraphEdge(from: ownerID, target: control.id, type: .association)
            ephemeralControlEdges.append(edge)
        }
    }
    
    private func handleControlAction(kind: ControlKind, ownerID: NodeID?) async {
        switch kind {
        case .undo:
            await undo()
        case .redo:
            await redo()
        case .configMode:
            isConfigMode.toggle()
        case .addChild:
            if let id = ownerID {
                await addChildToNode(id)
            }
        case .deleteNode:
            if let id = ownerID {
                await deleteNode(withID: id)
            }
        case .toggleExpansion:
            if let id = ownerID {
                await toggleExpansion(for: id)
            }
        }
        
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    private func addChildToNode(_ parentID: NodeID) async {
        guard let parent = nodes.first(where: { $0.id == parentID }) else { return }
        let child = await addNode(at: parent.position + CGPoint(x: 60, y: 0))
        await addEdge(from: parentID, target: child.id, type: .hierarchy)
    }
    
    public func updateControlPosition(controlID: NodeID, to newPosition: CGPoint) {
        if let index = ephemeralControlNodes.firstIndex(where: { $0.id == controlID }) {
            var control = ephemeralControlNodes[index]
            control.position = newPosition
            ephemeralControlNodes[index] = control
        }
    }
    
    public func toggleControlVisibility(kind: ControlKind, ownerID: NodeID?) {
        if let ownerID = ownerID {
            var configs = uiConfig[ownerID] ?? []
            if let index = configs.firstIndex(where: { $0.kind == kind }) {
                configs[index].isVisible.toggle()
            } else {
                configs.append(ControlConfig(kind: kind, isVisible: false))
            }
            uiConfig[ownerID] = configs
        } else {
            if let index = globalUiConfig.firstIndex(where: { $0.kind == kind }) {
                globalUiConfig[index].isVisible.toggle()
            } else {
                globalUiConfig.append(ControlConfig(kind: kind, isVisible: false))
            }
        }
        updateEphemerals(selectedNodeID: ownerID)
        pushUndo()
    }
    
    // MARK: - Persistence (Extend Existing Save/Load)
        
    // MARK: - Init Hook (Subscribe to Changes)
    
    // Call this in main init after setting up other publishers
    public func setupControlSubscriptions(selectedNodePublisher: AnyPublisher<NodeID?, Never>) {
        selectedNodePublisher
            .combineLatest(changesPublisher)
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] selectedID, _ in
                self?.updateEphemerals(selectedNodeID: selectedID)
            }
            .store(in: &cancellables)
    }
}

// NEW: Config Struct (Codable)
public struct ControlConfig: Codable, Equatable {
    public let kind: ControlKind
    public var isVisible: Bool = true
    public var priority: Int = 0
    // Extend with relativeOffset: CGPoint if persisting positions
}
