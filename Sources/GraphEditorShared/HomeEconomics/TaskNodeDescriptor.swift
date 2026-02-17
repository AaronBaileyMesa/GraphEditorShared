// Sources/GraphEditorShared/HomeEconomics/TaskNodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for TaskNode with status-aware behavior
@available(iOS 16.0, watchOS 9.0, *)
struct TaskNodeDescriptor: NodeTypeDescriptor {
    let node: TaskNode

    init(node: TaskNode) {
        self.node = node
    }

    // MARK: - Physics Configuration

    var mass: CGFloat {
        1.0  // Standard mass
    }

    var physicsRadius: CGFloat {
        node.radius
    }

    var constraints: [NodeConstraint] {
        []  // Tasks move freely
    }

    // MARK: - Visual Configuration

    var renderer: NodeRenderer {
        CircleNodeRenderer()  // Could use RectangleNodeRenderer for variety
    }

    var visualMultiplier: CGFloat {
        1.1
    }

    var baseFillColor: Color {
        node.fillColor  // Status-dependent color
    }

    var icon: NodeIcon? {
        switch node.taskType {
        // Top-level tasks
        case .plan: return .systemName("list.clipboard")
        case .shop: return .systemName("cart.fill")
        case .prep: return .systemName("fork.knife.circle")
        case .cook: return .systemName("flame.fill")
        case .assemble: return .systemName("rectangle.3.group")
        case .serve: return .systemName("fork.knife")
        case .cleanup: return .systemName("paintbrush.fill")

        // Prep subtasks
        case .prepMeat: return .systemName("flame.circle")
        case .prepVegetables: return .systemName("leaf.circle")
        case .prepSauces: return .systemName("drop.circle")
        case .prepShells: return .systemName("circle.grid.2x2")
        case .prepToppings: return .systemName("square.stack.3d.up")

        // Assembly subtasks
        case .assemblySetup: return .systemName("square.grid.3x3")
        case .assemblyBuild: return .systemName("hands.sparkles")
        case .assemblyPlate: return .systemName("checkmark.circle")
        }
    }

    // MARK: - Interaction Configuration

    var tapBehavior: NodeTapBehavior {
        .select  // Tasks are interactive
    }

    var isCollapsible: Bool {
        !node.children.isEmpty  // Only collapsible if has subtasks
    }

    var dragBehavior: NodeDragBehavior? {
        nil
    }

    // MARK: - Menu Configuration

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let task = node as? TaskNode else { return [] }

        return [
            .info([
                .text(task.taskType.rawValue.capitalized),
                .label("Status", task.status.rawValue.capitalized),
                .label("Time", "\(task.estimatedTime) min")
            ]),
            .actions([
                .button("Start Task") {
                    context.dismiss()
                },
                .button("Mark Complete") {
                    context.dismiss()
                },
                .divider,
                .button("Edit Task") {
                    context.dismiss()
                }
            ])
        ]
    }

    // MARK: - Animation Configuration

    var animations: NodeAnimationSet {
        .default
    }

    // MARK: - Haptic Configuration

    var haptics: NodeHapticSet {
        .init(
            tap: .click,
            drag: .click,
            drop: .click,
            stateChange: node.status == .completed ? .success : .click
        )
    }
}
