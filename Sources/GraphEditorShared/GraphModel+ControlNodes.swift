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
        
        // Per-node controls only (no globals)
        if let ownerID = selectedNodeID {
            addControlsForNode(ownerID)
        }
        
        // NEW: Final duplicate ID scan (prevents crash cause)
        var seenIDs = Set<NodeID>()
        ephemeralControlNodes.removeAll { control in
            if seenIDs.contains(control.id) {
                Self.controlLogger.warning("Removed duplicate control ID: \(control.id.uuidString.prefix(8))")
                return true
            }
            seenIDs.insert(control.id)
            return false
        }
        
        objectWillChange.send()
        changesPublisher.send()
    }
    
    private func addControlsForNode(_ ownerID: NodeID) {
        // Clear existing for this owner to prevent duplicates
        ephemeralControlNodes.removeAll { $0.ownerID == ownerID }
        ephemeralControlEdges.removeAll { $0.from == ownerID }
        
        guard let owner = nodes.first(where: { $0.id == ownerID })?.unwrapped else {
            Self.controlLogger.warning("Owner node not found for controls: \(ownerID.uuidString.prefix(8))")
            return
        }
        
        let kinds: [ControlKind] = [.edit, .addChild, .deleteNode, .toggleExpansion]  // Based on screenshots: pencil, plus, trash, and toggle
        
        let filtered = kinds.filter { kind in
            uiConfig[ownerID]?.first(where: { $0.kind == kind })?.isVisible ?? true
        }
        
        let sortedFiltered = filtered.sorted { kind1, kind2 in
            let priority1 = uiConfig[ownerID]?.first(where: { $0.kind == kind1 })?.priority ?? 0
            let priority2 = uiConfig[ownerID]?.first(where: { $0.kind == kind2 })?.priority ?? 0
            return priority1 < priority2
        }
        
        let freeSlots = getFreeSlots(for: ownerID)
        let spacing: CGFloat = 40.0
        
        for (index, kind) in sortedFiltered.enumerated() {
            // Skip if kind already exists (duplicate check)
            if ephemeralControlNodes.contains(where: { $0.kind == kind && $0.ownerID == ownerID }) { continue }
            
            let angle = freeSlots[index % freeSlots.count]
            let dx = cos(angle * .pi / 180) * spacing
            let dy = sin(angle * .pi / 180) * spacing
            let position = CGPoint(x: owner.position.x + dx, y: owner.position.y + dy)
            let clampedPos = clampPosition(position)
            
            let control = ControlNode(
                position: clampedPos,
                ownerID: ownerID,
                kind: kind
            )
            
            // NEW: Check for duplicate ID before append (extra safety)
            if ephemeralControlNodes.contains(where: { $0.id == control.id }) {
                Self.controlLogger.warning("Skipping duplicate control ID: \(control.id.uuidString.prefix(8))")
                continue
            }
            
            ephemeralControlNodes.append(control)
            ephemeralControlEdges.append(GraphEdge(from: ownerID, target: control.id, type: .spring))  // Assuming .spring for dotted attachment
            
            // NEW: Debug log for positioning
            Self.controlLogger.debug("Added control \(String(describing: kind)) for node \(ownerID.uuidString.prefix(8)) at model pos (\(clampedPos.x), \(clampedPos.y))")
        }
    }
    
    // MARK: - Action Dispatching (Completed based on truncation/context)
    public func handleControlTap(on control: ControlNode) async {
        guard let ownerID = control.ownerID else {
            Self.controlLogger.warning("Control tap with no owner: \(String(describing: control.kind))")
            return
        }
        
        Self.controlLogger.debug("Handling tap on control \(String(describing: control.kind)) for node \(ownerID.uuidString.prefix(8))")
        
        switch control.kind {
        case .edit:
            editingNodeID = ownerID  // Triggers sheet in UI
        case .addChild:
            await addChildToNode(ownerID)
        case .deleteNode:
            await deleteSelected(selectedNodeID: ownerID, selectedEdgeID: nil)
        case .toggleExpansion:
            Self.controlLogger.debug("Toggle expansion for node \(ownerID.uuidString.prefix(8))")
            await toggleExpansion(for: ownerID)
        // Add other cases if more kinds exist
        default:
            Self.controlLogger.warning("Unhandled control kind: \(String(describing: control.kind))")
        }
    }
    
    private func addChildToNode(_ parentID: NodeID) async {
        // NEW: Pause ephemeral updates and simulation to prevent mid-add mutations/duplicates
        let originalCancellables = cancellables  // Save to restore
        cancellables.removeAll()  // Temporarily disable subscriptions
        physicsEngine.isPaused = true
        defer {
            cancellables = originalCancellables  // Restore
            physicsEngine.isPaused = false
            Self.controlLogger.debug("Resumed updates after add child")
        }
        
        guard let parentIndex = nodes.firstIndex(where: { $0.id == parentID }) else {
            Self.controlLogger.warning("Parent not found for add child: \(parentID.uuidString.prefix(8))")
            return
        }
        
        let parent = nodes[parentIndex].unwrapped
        
        // NEW: Random offset to avoid position overlap (prevents velocity explosions)
        let angle = CGFloat.random(in: 0 ..< .pi * 2)
        let dist = parent.radius + Constants.App.nodeModelRadius + 40  // Assume Constants exists; adjust
        let childPos = parent.position + CGPoint(x: dist * cos(angle), y: dist * sin(angle))
        
        let newChild = Node(label: nextNodeLabel, position: childPos)  // Use nextNodeLabel from core model
        nextNodeLabel += 1
        let anyChild = AnyNode(newChild)
        
        // NEW: Check for duplicate ID before append
        if nodes.contains(where: { $0.id == anyChild.id }) {
            Self.controlLogger.error("Duplicate node ID detected: \(anyChild.id.uuidString.prefix(8)) – aborting add")
            return
        }
        
        nodes.append(anyChild)
        await addEdge(from: parentID, target: newChild.id, type: .hierarchy)
        
        objectWillChange.send()
        invalidateHiddenNodesCache()
        await resumeSimulation()
        
        // NEW: Debug log
        Self.controlLogger.debug("Added child \(newChild.id.uuidString.prefix(8)) to \(parentID.uuidString.prefix(8)) at (\(childPos.x), \(childPos.y))")
    }
    
    public func updateControlPosition(controlID: NodeID, to newPosition: CGPoint) {
        if let index = ephemeralControlNodes.firstIndex(where: { $0.id == controlID }) {
            var control = ephemeralControlNodes[index]
            control.position = newPosition
            ephemeralControlNodes[index] = control
        }
    }
    
    public func toggleControlVisibility(kind: ControlKind, ownerID: NodeID?) {
        guard let ownerID = ownerID else {
            Self.controlLogger.warning("Toggle visibility called with nil owner – ignoring (globals removed)")
            return
        }
        
        var configs = uiConfig[ownerID] ?? []
        if let index = configs.firstIndex(where: { $0.kind == kind }) {
            configs[index].isVisible.toggle()
        } else {
            configs.append(ControlConfig(kind: kind, isVisible: false))
        }
        uiConfig[ownerID] = configs
        
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
