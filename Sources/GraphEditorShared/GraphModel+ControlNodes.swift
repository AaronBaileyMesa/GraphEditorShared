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
        let controlRadius: CGFloat = Constants.App.nodeModelRadius * 0.5  // Smaller distinct size
        
        // Tunable base distance (~1/2 combined radii + padding)
        let baseDistance = (ownerRadius + controlRadius) / 2 + 5.0
        
        // Existing: Get filtered/sorted kinds
        let nodeKinds: [ControlKind] = [.toggleExpansion, .addChild, .deleteNode]  // Ordered by priority
        
        let filtered = nodeKinds.filter { kind in
            uiConfig[ownerID]?.first(where: { $0.kind == kind })?.isVisible ?? true
        }
        
        let sortedFiltered = filtered.sorted { kind1, kind2 in
            let priority1 = uiConfig[ownerID]?.first(where: { $0.kind == kind1 })?.priority ?? 0
            let priority2 = uiConfig[ownerID]?.first(where: { $0.kind == kind2 })?.priority ?? 0
            return priority1 > priority2
        }
        
        let freeSlots = getFreeSlots(for: ownerID)
        let maxControls = min(sortedFiltered.count, freeSlots.count)  // Limit to available slots (e.g., 3 on watchOS via const later)
        
        for index in 0..<maxControls {
            let kind = sortedFiltered[index]
            let angleDeg = freeSlots[index]
            let angleRad = angleDeg * .pi / 180  // Convert to radians
            let offset = CGPoint(x: cos(angleRad) * baseDistance, y: sin(angleRad) * baseDistance)
            let position = ownerPos + offset
            
            let config = uiConfig[ownerID]?.first(where: { $0.kind == kind }) ?? ControlConfig(kind: kind)
            
            var control = ControlNode(
                position: position,
                ownerID: ownerID,
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
            
            // Attach with spring edge (visual for now; physics later)
            let edge = GraphEdge(from: ownerID, target: control.id, type: .spring)
            ephemeralControlEdges.append(edge)
        }
        // Debug log for tuning (remove later)
        Self.controlLogger.debug("Added \(maxControls) controls at positions: \(self.ephemeralControlNodes.map { $0.position })")
        
        // Brief simulation to "make room" via repulsion/collision
        Task {
            await resumeSimulation()
            try? await Task.sleep(for: .milliseconds(500))  // Tune: 0.5s settling
            await pauseSimulation()
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
                await addChildToNode(id)  // Existing func; enhance below for same-type
            }
        case .deleteNode:
            if let id = ownerID {
                await deleteNode(withID: id)
            }
        case .toggleExpansion:
            if let id = ownerID, let toggleIndex = nodes.firstIndex(where: { $0.id == id && $0.unwrapped is ToggleNode }) {
                var updated = nodes[toggleIndex]
                if var toggle = updated.unwrapped as? ToggleNode {
                    toggle.isExpanded.toggle()
                    updated = AnyNode(toggle)
                    nodes[toggleIndex] = updated
                    objectWillChange.send()
                }
            }
        }
        
#if os(watchOS)
        WKInterfaceDevice.current().play(.click)
#endif
    }
    
    private func addChildToNode(_ parentID: NodeID) async {
        guard let parentIndex = nodes.firstIndex(where: { $0.id == parentID }) else { return }
        let parent = nodes[parentIndex]
        let childPos = parent.position + CGPoint(x: 60, y: 0)
        
        let childID = NodeID()  // Generate ID first
        let child: AnyNode
        
        if parent.unwrapped is ToggleNode {
            let toggleChild = ToggleNode(id: childID, label: self.nextNodeLabel, position: childPos)
            child = AnyNode(toggleChild)
            self.nextNodeLabel += 1
        } else {
            let basicChild = Node(id: childID, label: self.nextNodeLabel, position: childPos)
            child = AnyNode(basicChild)
            self.nextNodeLabel += 1
        }
        
        nodes.append(child)  // Add directly (mirrors likely addNode logic)
        await addEdge(from: parentID, target: childID, type: .hierarchy)
        
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
}

// NEW: Config Struct (Codable)
public struct ControlConfig: Codable, Equatable {
    public let kind: ControlKind
    public var isVisible: Bool = true
    public var priority: Int = 0
    // Extend with relativeOffset: CGPoint if persisting positions
}
