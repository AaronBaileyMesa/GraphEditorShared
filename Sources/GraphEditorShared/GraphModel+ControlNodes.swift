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
    
    fileprivate static let controlLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "GraphEditorShared", category: "controlnodes")  // Unique name
    
    private static let controlAngles: [CGFloat] = [0, 45, 90, 135, 180, 225, 270, 315]  // Degrees, starting at 0° (right)
    
    private func getFreeSlots(for ownerID: NodeID) -> [CGFloat] {
        // v1: Assume no occupations – return all slots
        // Future: Check priorityEdges[ownerID] ?? [], calculate occupied angles from edge directions,
        //         filter out slots within ±22.5° of occupied, return remaining sorted.
        return Self.controlAngles  // Use static
    }
    
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
        // Clear existing globals first to prevent duplicates
        ephemeralControlNodes.removeAll { $0.ownerID == nil }
        ephemeralControlEdges.removeAll { $0.from == nil || $0.target == nil }  // Assuming globals have nil owner
        
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
            return priority1 < priority2
        }
        
        let spacing: CGFloat = 40.0
        for (index, kind) in sortedFiltered.enumerated() {
            // Skip if kind already exists (duplicate check)
            if ephemeralControlNodes.contains(where: { $0.kind == kind && $0.ownerID == nil }) { continue }
            
            let angle = CGFloat(index) * (360 / CGFloat(sortedFiltered.count))
            let dx = cos(angle * .pi / 180) * spacing
            let dy = sin(angle * .pi / 180) * spacing
            let position = CGPoint(x: centroid.x + dx, y: centroid.y + dy)
            let clampedPos = clampPosition(position)
            
            let control = ControlNode(
                position: clampedPos,
                ownerID: nil,
                kind: kind,
                isVisible: true,  // Default or from config
                priority: globalUiConfig.first(where: { $0.kind == kind })?.priority ?? 0,
                action: { [weak self] in Task { await self?.handleControlAction(kind: kind, ownerID: nil) } }  // Wrap async in Task
            )
            ephemeralControlNodes.append(control)
            
            // Add ephemeral spring edge to centroid if desired
            // Example: ephemeralControlEdges.append(GraphEdge(from: nil, target: control.id, type: .spring))
        }
    }
    
    private func addControlsForNode(_ ownerID: NodeID) {
        // Clear existing for this owner to prevent duplicates
        ephemeralControlNodes.removeAll { $0.ownerID == ownerID }
        ephemeralControlEdges.removeAll { $0.from == ownerID || $0.target == ownerID }
        
        guard let owner = nodes.first(where: { $0.id == ownerID })?.unwrapped else { return }
        
        var nodeKinds: [ControlKind] = [.edit, .addChild, .deleteNode]  // Example; adjust per mode
        
        // Filter visible
        let filtered = nodeKinds.filter { kind in
            uiConfig[ownerID]?.first(where: { $0.kind == kind })?.isVisible ?? true
        }
        
        let sortedFiltered = filtered.sorted { kind1, kind2 in
            let priority1 = uiConfig[ownerID]?.first(where: { $0.kind == kind1 })?.priority ?? 0
            let priority2 = uiConfig[ownerID]?.first(where: { $0.kind == kind2 })?.priority ?? 0
            return priority1 < priority2
        }
        
        let freeSlots = getFreeSlots(for: ownerID)
        let spacing: CGFloat = owner.radius + 20.0
        
        for (index, kind) in sortedFiltered.enumerated() {
            // Skip if kind already exists for owner (duplicate check)
            if ephemeralControlNodes.contains(where: { $0.kind == kind && $0.ownerID == ownerID }) { continue }
            
            guard index < freeSlots.count else { break }  // Limit to available slots
            
            let angle = freeSlots[index]
            let dx = cos(angle * .pi / 180) * spacing
            let dy = sin(angle * .pi / 180) * spacing
            let position = CGPoint(x: owner.position.x + dx, y: owner.position.y + dy)
            let clampedPos = clampPosition(position)
            
            let control = ControlNode(
                position: clampedPos,
                ownerID: ownerID,
                kind: kind,
                isVisible: true,  // Default or from config
                priority: uiConfig[ownerID]?.first(where: { $0.kind == kind })?.priority ?? 0,
                action: { [weak self] in Task { await self?.handleControlAction(kind: kind, ownerID: ownerID) } }  // Wrap async in Task
            )
            ephemeralControlNodes.append(control)
            
            // Add ephemeral spring edge to owner
            ephemeralControlEdges.append(GraphEdge(from: ownerID, target: control.id, type: .spring))
        }
    }
    
    private func handleControlAction(kind: ControlKind, ownerID: NodeID?) async {
        guard let ownerID else {
            Self.controlLogger.warning("Action \(kind.rawValue) triggered without ownerID")
            return
        }
        switch kind {
        case .undo:
            await undo()
        case .redo:
            await redo()
        case .configMode:
            isConfigMode.toggle()
        case .edit:
            Self.controlLogger.debug("Edit triggered for node \(ownerID.uuidString.prefix(8))")
            editingNodeID = ownerID  // Triggers sheet in UI
        case .addChild:
            await addChildToNode(ownerID)
        case .deleteNode:  // Assuming you renamed .delete to .deleteNode as per previous fixes
            await deleteSelected(selectedNodeID: ownerID, selectedEdgeID: nil)
        case .toggleExpansion:
            Self.controlLogger.debug("Toggle expansion for node \(ownerID.uuidString.prefix(8))")
            await toggleExpansion(for: ownerID)
        }
    }
    private func addChildToNode(_ parentID: NodeID) async {
        let newChild = Node(label: nodes.count + 1, position: .zero)  // Example; adjust
        nodes.append(AnyNode(newChild))
        await addEdge(from: parentID, target: newChild.id, type: .hierarchy)
        
        objectWillChange.send()
        invalidateHiddenNodesCache()
        await resumeSimulation()
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
    
    private func clampPosition(_ pos: CGPoint) -> CGPoint {
        let minX = CGFloat(0), minY = CGFloat(0)  // Or simulationBounds lower if defined
        let maxX = self.physicsEngine.simulationBounds.width, maxY = self.physicsEngine.simulationBounds.height
        return CGPoint(
            x: pos.x.clamped(to: minX...maxX),
            y: pos.y.clamped(to: minY...maxY)
        )
    }
}

// NEW: Config Struct (Codable)
public struct ControlConfig: Codable, Equatable {
    public let kind: ControlKind
    public var isVisible: Bool = true
    public var priority: Int = 0
    // Extend with relativeOffset: CGPoint if persisting positions
}
