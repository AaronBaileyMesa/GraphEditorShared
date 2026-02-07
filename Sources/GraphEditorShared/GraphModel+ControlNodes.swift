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
    
    // NEW: Flag to prevent recursive updates in the subscription sink
    
    public func getFreeSlots(for ownerID: NodeID) -> [CGFloat] {
        // v1: Assume no occupations – return all slots
        // Future: Check priorityEdges[ownerID] ?? [], calculate occupied angles from edge directions,
        //         filter out slots within ±22.5° of occupied, return remaining sorted.
        return Self.controlAngles  // Use static
    }
    
    // MARK: - Ephemeral Management
    @MainActor
    public func updateEphemerals(selectedNodeID: NodeID?) async {
        #if DEBUG
        Self.controlLogger.debug("updateEphemerals started for selectedNodeID: \(selectedNodeID?.uuidString.prefix(8) ?? "nil")")
        #endif
        
        // Clear previous ephemerals safely
        if let previousOwnerID = ephemeralControlNodes.first?.ownerID {
            #if DEBUG
            Self.controlLogger.debug("Clearing previous ephemerals for owner: \(previousOwnerID.uuidString.prefix(8))")
            #endif
            await removeEphemerals(for: previousOwnerID)
        } else {
            ephemeralControlNodes.removeAll()
            ephemeralControlEdges.removeAll()
        }
        
        // Generate new controls if a node is selected
        if let ownerID = selectedNodeID {
            await addControlsForNode(ownerID)
        }
        
        // NEW: Final duplicate ID scan (prevents crashes from duplicates)
        var seenIDs = Set<NodeID>()
        ephemeralControlNodes.removeAll { control in
            if seenIDs.contains(control.id) {
                Self.controlLogger.warning("Removed duplicate control ID: \(control.id.uuidString.prefix(8))")
                return true
            }
            seenIDs.insert(control.id)
            return false
        }
        
        #if DEBUG
        Self.controlLogger.debug("Ephemerals updated: \(self.ephemeralControlNodes.count) controls for owner \(selectedNodeID?.uuidString.prefix(8) ?? "none") – kinds: \(self.ephemeralControlNodes.map { $0.kind.rawValue }.joined(separator: ", "))")
        #endif
    }
    
    // MARK: - Live Repositioning for Drags
    @MainActor
    public func repositionEphemerals(for ownerID: NodeID, to newPosition: CGPoint) {
        #if DEBUG
        Self.controlLogger.debug("repositionEphemerals: owner=\(ownerID.uuidString.prefix(8)) newPos=(\(newPosition.x, format: .fixed(precision: 1)), \(newPosition.y, format: .fixed(precision: 1)))")
        #endif
        
        for index in ephemeralControlNodes.indices where ephemeralControlNodes[index].ownerID == ownerID {
            var control = ephemeralControlNodes[index]
            let spacing: CGFloat = 40.0  // Reuse from addControlsForNode
            let angle = control.relativeAngle  // NEW: Use stored value (stable across drags)
            let deltaX = cos(angle * .pi / 180) * spacing
            let deltaY = sin(angle * .pi / 180) * spacing
            let oldPos = control.position
            // Don't clamp - maintain exact 40pt offset from owner
            control.position = CGPoint(x: newPosition.x + deltaX, y: newPosition.y + deltaY)
            control.velocity = .zero  // Reset velocity during manual drag to prevent drift
            ephemeralControlNodes[index] = control
            
            #if DEBUG
            let distance = hypot(control.position.x - newPosition.x, control.position.y - newPosition.y)
            Self.controlLogger.debug("  Control \(control.kind.rawValue): angle=\(angle, format: .fixed(precision: 1))° oldPos=(\(oldPos.x, format: .fixed(precision: 1)), \(oldPos.y, format: .fixed(precision: 1))) newPos=(\(control.position.x, format: .fixed(precision: 1)), \(control.position.y, format: .fixed(precision: 1))) distance=\(distance, format: .fixed(precision: 1))")
            #endif
        }
        
        #if DEBUG
        Self.controlLogger.debug("repositionEphemerals complete: \(self.ephemeralControlNodes.count) controls updated")
        #endif
        objectWillChange.send()  // Trigger redraw
    }
    
    private func addControlsForNode(_ ownerID: NodeID) async {
        // Clear existing for this owner to prevent duplicates
        ephemeralControlNodes.removeAll { $0.ownerID == ownerID }
        ephemeralControlEdges.removeAll { $0.from == ownerID }
        
        guard let ownerIndex = nodes.firstIndex(where: { $0.id == ownerID }) else {
            Self.controlLogger.warning("Owner node not found for controls: \(ownerID.uuidString.prefix(8))")
            return
        }
        
        
        // Stabilize existing nodes before adding ephemerals by zeroing all velocities
        for index in nodes.indices {
            let currentNode = nodes[index].unwrapped
            nodes[index] = AnyNode(currentNode.with(position: currentNode.position, velocity: .zero))
        }
        // Write the stabilized nodes back to persist the zeroed velocities
        self.nodes = nodes
        physicsEngine.temporaryDampingBoost(steps: 30)
        
        let owner = nodes[ownerIndex].unwrapped

        let kinds: [ControlKind] = [.edit, .addChild, .addEdge, .delete, .duplicate, .addToggleChild]
        
        // NEW: Contextual filtering - show only relevant controls based on node state
        let isCollapsible = (owner as? Node)?.isCollapsible ?? false
        let hierarchyChildren = edges.filter { $0.from == ownerID && $0.type == .hierarchy }
        let hasChildren = !hierarchyChildren.isEmpty
        let childCount = hierarchyChildren.count
        
        let contextuallyFiltered = kinds.filter { kind in
            switch kind {
            case .addChild:
                // Only show for collapsible nodes (plain children can only be added to collapsible parents)
                // Hide if node already has children (to avoid mixing plain and toggle children)
                return isCollapsible && !hasChildren
                
            case .addToggleChild:
                // Only show for collapsible nodes (toggle children can only be added to collapsible parents)
                return isCollapsible
                
            case .addEdge:
                // Hide if node already has 6+ hierarchy children (likely cluttered)
                return childCount < 6
                
            case .duplicate:
                // Always allow duplication
                return true
                
            case .edit:
                // Hide if node has no contents to edit
                return !owner.contents.isEmpty || true  // Keep visible for now to allow adding content
                
            case .delete:
                // Always allow deletion
                return true
            }
        }
        
        let filtered = contextuallyFiltered.filter { kind in
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
            let deltaX = cos(angle * .pi / 180) * spacing
            let deltaY = sin(angle * .pi / 180) * spacing

            let position = CGPoint(x: owner.position.x + deltaX, y: owner.position.y + deltaY)
            
            let control = ControlNode(
                position: position,
                ownerID: ownerID,
                kind: kind,
                relativeAngle: angle  // Store for stable repositioning
            )
            
            #if DEBUG
            let distance = hypot(position.x - owner.position.x, position.y - owner.position.y)
            Self.controlLogger.debug("  Created control \(kind.rawValue): angle=\(angle, format: .fixed(precision: 1))° pos=(\(position.x, format: .fixed(precision: 1)), \(position.y, format: .fixed(precision: 1))) distance=\(distance, format: .fixed(precision: 1))")
            #endif
            
            ephemeralControlNodes.append(control)
            
            // Create visual edge (association type - no physics forces)
            let edge = GraphEdge(from: ownerID, target: control.id, type: .association)
            ephemeralControlEdges.append(edge)
        }
        
        // NEW: Update owner in nodes after changes
        nodes[ownerIndex] = AnyNode(owner)
        
        objectWillChange.send()
        invalidateHiddenNodesCache()
        
        // Controls are already positioned correctly at exact 40pt spacing
        // No physics simulation needed - prevents drift from intended positions
    }
    
    private func removeEphemerals(for ownerID: NodeID) async {
        // NEW: Stabilize before removal for smooth contraction
        for index in nodes.indices {
            let currentNode = nodes[index].unwrapped
            nodes[index] = AnyNode(currentNode.with(position: currentNode.position, velocity: .zero))
        }
        physicsEngine.temporaryDampingBoost(steps: 20)
        
        ephemeralControlNodes.removeAll { $0.ownerID == ownerID }
        ephemeralControlEdges.removeAll { $0.from == ownerID }
        
        objectWillChange.send()
        invalidateHiddenNodesCache()
        
        // Don't run simulation after removal - it can move the owner node from its dragged position
        // The graph will stabilize naturally when simulation resumes
    }
    
    @MainActor
    public func handleControlTap(control: ControlNode) async {
        Self.controlLogger.debug("Handling tap on control \(String(describing: control.kind)) for owner \(control.ownerID?.uuidString.prefix(8) ?? "nil")")

        guard control.ownerID != nil else {
            Self.controlLogger.warning("Control tap with nil ownerID – ignoring")
            return
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
        
        Task { await updateEphemerals(selectedNodeID: ownerID) }  // Async to match new signature
        pushUndo()
    }
    
    // MARK: - Init Hook (Subscribe to Changes)
    // Call this in main init after setting up other publishers
    public func setupControlSubscriptions(selectedNodePublisher: AnyPublisher<NodeID?, Never>) {
        selectedNodePublisher
            .combineLatest(changesPublisher)
            .sink { [weak self] selectedID, _ in
                guard let self = self else { return }
                guard !self.isUpdatingEphemerals else {
                    Self.controlLogger.warning("Skipping ephemeral update due to re-entrancy guard")
                    return
                }
                
                self.isUpdatingEphemerals = true
                defer { self.isUpdatingEphemerals = false }
                
                Task {
                    await self.updateEphemerals(selectedNodeID: selectedID)
                    Self.controlLogger.debug("Completed ephemeral update for selectedID: \(selectedID?.uuidString.prefix(8) ?? "nil") via subscription")
                }
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
