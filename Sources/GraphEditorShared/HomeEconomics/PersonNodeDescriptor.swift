// Sources/GraphEditorShared/HomeEconomics/PersonNodeDescriptor.swift

import SwiftUI
import Foundation

/// Type descriptor for PersonNode
@available(iOS 16.0, watchOS 9.0, *)
struct PersonNodeDescriptor: NodeTypeDescriptor {
    let node: PersonNode

    init(node: PersonNode) {
        self.node = node
    }

    // MARK: - Physics Configuration

    var mass: CGFloat {
        1.0
    }

    var physicsRadius: CGFloat {
        node.radius
    }

    var constraints: [NodeConstraint] {
        // Note: We can't easily determine which table this person is seated at from the PersonNode alone
        // The seating relationship is stored in TableNode.seatingAssignments
        // This constraint will be resolved at runtime via the physics engine's constraint context
        [SeatedPersonConstraint(personID: node.id)]
    }

    // MARK: - Visual Configuration

    var renderer: NodeRenderer {
        PersonNodeRenderer()
    }

    var visualMultiplier: CGFloat {
        1.0
    }

    var baseFillColor: Color {
        node.fillColor
    }

    var icon: NodeIcon? {
        .systemName("person.fill")
    }

    // MARK: - Interaction Configuration

    var tapBehavior: NodeTapBehavior {
        .select
    }

    var isCollapsible: Bool {
        false
    }

    var dragBehavior: NodeDragBehavior? {
        nil
    }

    // MARK: - Menu Configuration

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        guard let person = node as? PersonNode else { return [] }

        var infoItems: [MenuItem] = [.text(person.name)]
        if let spice = person.defaultSpiceLevel {
            infoItems.append(.label("Spice Level", spice.capitalized))
        }
        if !person.dietaryRestrictions.isEmpty {
            infoItems.append(.label("Restrictions", person.dietaryRestrictions.joined(separator: ", ")))
        }

        return [
            .info(infoItems),
            .actions([
                .button("Assign to Table") {
                    context.dismiss()
                },
                .button("Edit Person") {
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
            drop: .directionDown,  // Satisfying when placing person
            stateChange: .success  // Success when assigned to table
        )
    }
}
