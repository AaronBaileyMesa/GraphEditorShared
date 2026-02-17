// Sources/GraphEditorShared/HomeEconomics/MealNodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for MealNode with workflow-aware behavior
@available(iOS 16.0, watchOS 9.0, *)
struct MealNodeDescriptor: NodeTypeDescriptor {
    let node: MealNode

    init(node: MealNode) {
        self.node = node
    }

    // MARK: - Physics Configuration

    var mass: CGFloat {
        2.0  // Slightly heavier than regular nodes
    }

    var physicsRadius: CGFloat {
        node.radius
    }

    var constraints: [NodeConstraint] {
        []  // Meals move freely
    }

    // MARK: - Visual Configuration

    var renderer: NodeRenderer {
        CircleNodeRenderer()  // Standard circle rendering
    }

    var visualMultiplier: CGFloat {
        1.3
    }

    var baseFillColor: Color {
        node.fillColor  // Delegatesто MealNode's color logic
    }

    var icon: NodeIcon? {
        .systemName("fork.knife")
    }

    // MARK: - Interaction Configuration

    var tapBehavior: NodeTapBehavior {
        .toggleExpansion  // Can expand/collapse task children
    }

    var isCollapsible: Bool {
        true
    }

    var dragBehavior: NodeDragBehavior? {
        nil  // Standard drag behavior
    }

    // MARK: - Menu Configuration

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let meal = node as? MealNode else { return [] }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        return [
            .info([
                .text(meal.name),
                .label("Type", meal.mealType.rawValue.capitalized),
                .label("Date", dateFormatter.string(from: meal.date)),
                .label("Servings", "\(meal.servings)")
            ]),
            .actions([
                .button("Start Workflow") {
                    // Will be connected to actual implementation
                    context.dismiss()
                },
                .button("Edit Meal") {
                    context.dismiss()
                },
                .divider,
                .button("Delete Meal") {
                    context.dismiss()
                }
            ])
        ]
    }

    // MARK: - Animation Configuration

    var animations: NodeAnimationSet {
        .default  // Standard animations
    }

    // MARK: - Haptic Configuration

    var haptics: NodeHapticSet {
        .init(
            tap: .click,
            drag: .click,
            drop: .click,
            stateChange: .success  // Success feedback when workflow state changes
        )
    }
}
