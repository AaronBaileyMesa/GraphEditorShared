// Sources/GraphEditorShared/HomeEconomics/TacoNodeDescriptor.swift

import SwiftUI
import Foundation

// MARK: - TacoNodeRenderer

/// Custom renderer for TacoNode that draws taco icons in GraphicsContext
@available(iOS 16.0, watchOS 9.0, *)
struct TacoNodeRenderer: NodeRenderer {
    let tacoNode: TacoNode
    
    func renderShape(
        context: inout GraphicsContext,
        node: any NodeProtocol,
        screenPosition: CGPoint,
        zoomScale: CGFloat,
        isSelected: Bool
    ) {
        print("🌮 TacoNodeRenderer.renderShape called for node \(node.label), shell: \(tacoNode.shell?.rawValue ?? "nil"), protein: \(tacoNode.protein?.rawValue ?? "nil")")
        
        let size = node.displayRadius * 2 * zoomScale
        let rect = CGRect(
            x: screenPosition.x - size / 2,
            y: screenPosition.y - size / 2,
            width: size,
            height: size
        )
        
        // Draw shell shape
        if let shell = tacoNode.shell {
            print("🌮 Drawing shell: \(shell.rawValue) at position \(screenPosition)")

            // For soft corn, draw second tortilla layer FIRST (so it's behind)
            if shell == .softCorn {
                let offset = size * 0.08
                var offsetRect = rect
                offsetRect.origin.x += offset
                offsetRect.origin.y += offset
                let backShellPath = makeShellPath(for: shell, in: offsetRect)
                context.fill(backShellPath, with: .color(shellColor(for: shell)))
                context.stroke(backShellPath, with: .color(.black.opacity(0.15)), lineWidth: 1)
            }

            // Draw main shell (on top of offset tortilla for soft corn)
            let shellPath = makeShellPath(for: shell, in: rect)
            context.fill(shellPath, with: .color(shellColor(for: shell)))
            context.stroke(shellPath, with: .color(.black.opacity(0.25)), lineWidth: shell == .softCorn ? 1.5 : 1)

            // Add char marks to flour tortillas
            if shell == .softFlour {
                context.drawLayer { layerContext in
                    layerContext.clip(to: shellPath)
                    drawTortillaCharMarks(context: &layerContext, in: rect)
                }
            }
            
            // Draw protein filling
            if let protein = tacoNode.protein {
                let fillingPath = makeFillingPath(for: shell, in: rect)
                context.fill(fillingPath, with: .color(proteinColor(for: protein)))

                // Add texture to filling
                context.drawLayer { layerContext in
                    layerContext.clip(to: fillingPath)
                    drawProteinTexture(context: &layerContext, protein: protein, shell: shell, in: rect)
                }
            }
        } else {
            // Fallback: circle
            let circlePath = Circle().path(in: rect)
            context.fill(circlePath, with: .color(node.fillColor))
        }
    }
    
    func renderView(
        node: any NodeProtocol,
        zoomScale: CGFloat,
        isSelected: Bool
    ) -> AnyView {
        // Fallback for SwiftUI rendering (not used in canvas)
        AnyView(
            Circle()
                .fill(node.fillColor)
                .frame(width: node.displayRadius * 2 * zoomScale, height: node.displayRadius * 2 * zoomScale)
        )
    }
    
    func visualBounds(
        for node: any NodeProtocol,
        at screenPosition: CGPoint,
        zoomScale: CGFloat
    ) -> CGRect {
        let radius = node.displayRadius * zoomScale
        return CGRect(
            x: screenPosition.x - radius,
            y: screenPosition.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }
    
    // MARK: - Helper Methods
    
    private func shellColor(for shell: ShellType) -> Color {
        switch shell {
        case .crunchy:
            return Color(red: 0.95, green: 0.77, blue: 0.20)
        case .softFlour:
            return Color(red: 0.96, green: 0.92, blue: 0.84)
        case .softCorn:
            return Color(red: 0.95, green: 0.85, blue: 0.55)
        }
    }
    
    private func proteinColor(for protein: ProteinType) -> Color {
        switch protein {
        case .beef:
            return Color(red: 0.50, green: 0.28, blue: 0.18)
        case .chicken:
            return Color(red: 0.88, green: 0.78, blue: 0.62)
        }
    }
    
    private func makeShellPath(for shell: ShellType, in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let centerY = rect.midY
        
        var path = Path()
        
        switch shell {
        case .crunchy:
            // Horizontal crescent
            let shellWidth = width * 0.8
            let shellHeight = shellWidth / 2
            
            path.move(to: CGPoint(x: centerX - shellWidth * 0.4, y: centerY - shellHeight * 0.5))
            path.addLine(to: CGPoint(x: centerX + shellWidth * 0.4, y: centerY - shellHeight * 0.5))
            path.addQuadCurve(
                to: CGPoint(x: centerX + shellWidth * 0.4, y: centerY + shellHeight * 0.5),
                control: CGPoint(x: centerX + shellWidth * 0.55, y: centerY)
            )
            path.addLine(to: CGPoint(x: centerX - shellWidth * 0.4, y: centerY + shellHeight * 0.5))
            path.addQuadCurve(
                to: CGPoint(x: centerX - shellWidth * 0.4, y: centerY - shellHeight * 0.5),
                control: CGPoint(x: centerX - shellWidth * 0.55, y: centerY)
            )
            
        case .softFlour:
            // Large circle
            let radius = width * 0.48
            path.addEllipse(in: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2))
            
        case .softCorn:
            // Smaller circle
            let radius = width * 0.48 * 0.625
            path.addEllipse(in: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2))
        }
        
        return path
    }
    
    private func makeFillingPath(for shell: ShellType, in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = rect.midX
        let centerY = rect.midY

        var path = Path()

        switch shell {
        case .crunchy:
            let fillWidth = width * 0.8 * 0.6
            let fillHeight = fillWidth / 2
            let fillRect = CGRect(
                x: centerX - fillWidth * 0.5,
                y: centerY - fillHeight * 0.5,
                width: fillWidth,
                height: fillHeight
            )
            path.addEllipse(in: fillRect)

        case .softFlour:
            let shellRadius = width * 0.48
            let fillRadius = shellRadius * 0.7
            path.addEllipse(in: CGRect(x: centerX - fillRadius, y: centerY - fillRadius, width: fillRadius * 2, height: fillRadius * 2))

        case .softCorn:
            let shellRadius = width * 0.48 * 0.625
            let fillRadius = shellRadius * 0.7
            path.addEllipse(in: CGRect(x: centerX - fillRadius, y: centerY - fillRadius, width: fillRadius * 2, height: fillRadius * 2))
        }

        return path
    }

    private func drawProteinTexture(context: inout GraphicsContext, protein: ProteinType, shell: ShellType, in rect: CGRect) {
        // Use node's ID to create unique but deterministic texture pattern for each taco
        let nodeSeed = tacoNode.id.hashValue

        // Calculate the actual filling bounds based on shell type
        let width = rect.width
        let centerX = rect.midX
        let centerY = rect.midY

        let fillingRect: CGRect
        let fillingRadius: CGFloat

        switch shell {
        case .crunchy:
            let fillWidth = width * 0.8 * 0.6
            let fillHeight = fillWidth / 2
            fillingRect = CGRect(
                x: centerX - fillWidth * 0.5,
                y: centerY - fillHeight * 0.5,
                width: fillWidth,
                height: fillHeight
            )
            fillingRadius = min(fillWidth, fillHeight) / 2

        case .softFlour:
            let shellRadius = width * 0.48
            fillingRadius = shellRadius * 0.7
            fillingRect = CGRect(
                x: centerX - fillingRadius,
                y: centerY - fillingRadius,
                width: fillingRadius * 2,
                height: fillingRadius * 2
            )

        case .softCorn:
            let shellRadius = width * 0.48 * 0.625
            fillingRadius = shellRadius * 0.7
            fillingRect = CGRect(
                x: centerX - fillingRadius,
                y: centerY - fillingRadius,
                width: fillingRadius * 2,
                height: fillingRadius * 2
            )
        }

        switch protein {
        case .chicken:
            // Chicken: diagonal grill marks with slight randomness in position
            let lineCount = 5
            let lineWidth = max(1.5, fillingRect.width * 0.04)

            // For circular fillings, extend lines to cover entire circle diameter
            let diagonal = sqrt(fillingRect.width * fillingRect.width + fillingRect.height * fillingRect.height)
            let spacing = diagonal / CGFloat(lineCount + 1)

            for index in 0..<lineCount {
                // Add slight variation to grill mark position based on node ID
                let jitter = pseudoRandom(seed: nodeSeed &+ (index * 31), range: spacing * 0.2) - spacing * 0.1

                // Position marks diagonally across the entire filling area
                let offset = spacing * CGFloat(index + 1) + jitter - diagonal * 0.5

                var path = Path()
                // Draw diagonal line from top-left to bottom-right
                path.move(to: CGPoint(
                    x: centerX + offset - diagonal * 0.5,
                    y: centerY - diagonal * 0.5
                ))
                path.addLine(to: CGPoint(
                    x: centerX + offset + diagonal * 0.5,
                    y: centerY + diagonal * 0.5
                ))
                context.stroke(path, with: .color(.black.opacity(0.4)), lineWidth: lineWidth)
            }

        case .beef:
            // Beef: speckle pattern unique to each taco node
            let speckleCount = 50
            let speckleSize = max(2.0, fillingRect.width * 0.08)

            for index in 0..<speckleCount {
                // Use polar coordinates for circular fillings, rectangular for crunchy
                let xPos: CGFloat
                let yPos: CGFloat

                if shell == .crunchy {
                    // Rectangular distribution for crunchy shell
                    xPos = fillingRect.minX + pseudoRandom(seed: nodeSeed &+ (index * 7), range: fillingRect.width)
                    yPos = fillingRect.minY + pseudoRandom(seed: nodeSeed &+ (index * 13), range: fillingRect.height)
                } else {
                    // Circular distribution for soft shells
                    let angle = pseudoRandom(seed: nodeSeed &+ (index * 7), range: .pi * 2)
                    let distance = sqrt(pseudoRandom(seed: nodeSeed &+ (index * 13), range: 1.0)) * fillingRadius
                    xPos = centerX + cos(angle) * distance
                    yPos = centerY + sin(angle) * distance
                }

                let specklePath = Path(ellipseIn: CGRect(
                    x: xPos - speckleSize / 2,
                    y: yPos - speckleSize / 2,
                    width: speckleSize,
                    height: speckleSize
                ))

                // Vary opacity for depth - all dark brown/black speckles
                let opacity = pseudoRandom(seed: nodeSeed &+ (index * 19), range: 0.3) + 0.3 // 0.3 to 0.6
                context.fill(specklePath, with: .color(.black.opacity(opacity)))
            }
        }
    }

    private func pseudoRandom(seed: Int, range: CGFloat) -> CGFloat {
        let hash = (seed &* 2654435761) % 2147483647
        return CGFloat(hash) / 2147483647.0 * range
    }

    private func drawTortillaCharMarks(context: inout GraphicsContext, in rect: CGRect) {
        // Brown char spots on flour tortillas
        // Calculate the actual tortilla circle bounds (radius is 48% of width)
        let radius = rect.width * 0.48
        let centerX = rect.midX
        let centerY = rect.midY
        let tortillaRect = CGRect(
            x: centerX - radius,
            y: centerY - radius,
            width: radius * 2,
            height: radius * 2
        )

        let charMarkCount = 12
        let baseSize = max(3.0, tortillaRect.width * 0.10)

        // Use node's ID to create unique but deterministic scorch pattern for each taco
        let nodeSeed = tacoNode.id.hashValue

        for index in 0..<charMarkCount {
            // Position char marks within the actual tortilla circle using polar coordinates
            // This ensures even distribution across the circular tortilla
            let angle = pseudoRandom(seed: nodeSeed &+ (index * 11), range: .pi * 2)
            let distance = sqrt(pseudoRandom(seed: nodeSeed &+ (index * 17), range: 1.0)) * radius

            let xPos = centerX + cos(angle) * distance
            let yPos = centerY + sin(angle) * distance

            // Use pseudoRandom for size variation (deterministic but unique per node)
            let sizeVariation = pseudoRandom(seed: nodeSeed &+ (index * 19), range: 0.8) + 0.6 // 0.6 to 1.4
            let size = baseSize * sizeVariation

            // Irregular char mark shape (slightly squished ellipse)
            let charRect = CGRect(
                x: xPos - size / 2,
                y: yPos - size / 2,
                width: size,
                height: size * 0.8
            )

            let charPath = Path(ellipseIn: charRect)

            // Brown char color with varying opacity
            let opacity = pseudoRandom(seed: nodeSeed &+ (index * 23), range: 0.25) + 0.15
            context.fill(charPath, with: .color(Color(red: 0.4, green: 0.25, blue: 0.1).opacity(opacity)))
        }
    }
}

/// Type descriptor for TacoNode with New Meal control
@available(iOS 16.0, watchOS 9.0, *)
struct TacoNodeDescriptor: NodeTypeDescriptor {
    let node: TacoNode

    init(node: TacoNode) {
        self.node = node
    }

    // MARK: - Physics Configuration

    var mass: CGFloat {
        2.0
    }

    var physicsRadius: CGFloat {
        node.radius
    }

    var constraints: [NodeConstraint] {
        []
    }

    // MARK: - Visual Configuration

    var renderer: NodeRenderer {
        TacoNodeRenderer(tacoNode: node)
    }

    var visualMultiplier: CGFloat {
        1.3
    }

    var baseFillColor: Color {
        .orange
    }

    var icon: NodeIcon? {
        nil  // Custom rendering handled in NodeView
    }

    // MARK: - Interaction Configuration

    var tapBehavior: NodeTapBehavior {
        .toggleExpansion
    }

    var isCollapsible: Bool {
        true
    }

    var dragBehavior: NodeDragBehavior? {
        nil
    }

    // MARK: - Menu Configuration

    func menuSections(for node: any NodeProtocol, context: MenuContext) -> [MenuSection] {
        [
            .info([
                .text("🌮 Taco Night")
            ]),
            .actions([
                .button("New Meal") {
                    // Will launch TacoNightWizard
                    context.dismiss()
                },
                .divider,
                .button("Delete") {
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
            stateChange: .success
        )
    }
}
