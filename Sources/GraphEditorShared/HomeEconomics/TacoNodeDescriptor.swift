// Sources/GraphEditorShared/HomeEconomics/TacoNodeDescriptor.swift
// swiftlint:disable file_length type_body_length identifier_name

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

            // Draw toppings on top of protein
            if !tacoNode.toppings.isEmpty {
                let fillingPath = makeFillingPath(for: shell, in: rect)
                drawToppings(context: &context, toppings: tacoNode.toppings, shell: shell, fillingPath: fillingPath, in: rect)
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
            let fillRadius = shellRadius * 0.56
            path.addEllipse(in: CGRect(x: centerX - fillRadius, y: centerY - fillRadius, width: fillRadius * 2, height: fillRadius * 2))

        case .softCorn:
            let shellRadius = width * 0.48 * 0.625
            let fillRadius = shellRadius * 0.7
            path.addEllipse(in: CGRect(x: centerX - fillRadius, y: centerY - fillRadius, width: fillRadius * 2, height: fillRadius * 2))
        }

        return path
    }

    // swiftlint:disable:next function_body_length
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
            fillingRadius = shellRadius * 0.56
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
        let hash = abs((seed &* 2654435761) % 2147483647)
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

    // MARK: - Topping Rendering

    /// Draws all selected toppings in layering order on top of the protein filling.
    private func drawToppings(
        context: inout GraphicsContext,
        toppings: [String],
        shell: ShellType,
        fillingPath: Path,
        in rect: CGRect
    ) {
        // Layering order: creamy bases first, then chunky veg, then fresh herbs, then heat
        let order = [
            "Sour Cream", "Guacamole", "Cheese",
            "Lettuce", "Tomatoes", "Onions", "Radishes",
            "Jalapeños", "Salsa", "Cilantro", "Lime",
            "Pickled Jalapeños", "Hot Sauce"
        ]
        for topping in order where toppings.contains(topping) {
            context.drawLayer { layerContext in
                layerContext.clip(to: fillingPath)
                drawTopping(topping, context: &layerContext, shell: shell, in: rect)
            }
        }
    }

    private func drawTopping(_ topping: String, context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        switch topping {
        case "Lettuce":           drawLettuce(context: &context, shell: shell, in: rect)
        case "Tomatoes":          drawTomatoes(context: &context, shell: shell, in: rect)
        case "Cheese":            drawCheese(context: &context, shell: shell, in: rect)
        case "Sour Cream":        drawSourCream(context: &context, shell: shell, in: rect)
        case "Guacamole":         drawGuacamole(context: &context, shell: shell, in: rect)
        case "Salsa":             drawSalsa(context: &context, shell: shell, in: rect)
        case "Onions":            drawOnions(context: &context, shell: shell, in: rect)
        case "Cilantro":          drawCilantro(context: &context, shell: shell, in: rect)
        case "Jalapeños":         drawFreshJalapeños(context: &context, shell: shell, in: rect)
        case "Hot Sauce":         drawHotSauce(context: &context, shell: shell, in: rect)
        case "Radishes":          drawRadishes(context: &context, shell: shell, in: rect)
        case "Lime":              drawLime(context: &context, shell: shell, in: rect)
        case "Pickled Jalapeños": drawPickledJalapeños(context: &context, shell: shell, in: rect)
        default: break
        }
    }

    /// Returns the filling radius for use in topping placement.
    private func fillingRadius(for shell: ShellType, in rect: CGRect) -> CGFloat {
        let width = rect.width
        switch shell {
        case .crunchy:
            let fillWidth = width * 0.8 * 0.6
            return min(fillWidth, fillWidth / 2) / 2
        case .softFlour:
            return width * 0.48 * 0.56
        case .softCorn:
            return width * 0.48 * 0.625 * 0.7
        }
    }

    // MARK: Lettuce — bright green shredded lines radiating from center
    private func drawLettuce(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue
        let count = 14
        let color = Color(red: 0.2, green: 0.75, blue: 0.2)

        for i in 0..<count {
            let angle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let len = pseudoRandom(seed: seed &+ i * 11, range: radius * 0.7) + radius * 0.15
            let width = pseudoRandom(seed: seed &+ i * 17, range: 2.5) + 1.0
            let startDist = pseudoRandom(seed: seed &+ i * 23, range: radius * 0.3)
            var path = Path()
            path.move(to: CGPoint(x: centerX + cos(angle) * startDist, y: centerY + sin(angle) * startDist))
            // Slight curve using a control point offset perpendicular
            let perpAngle = angle + .pi / 2
            let cx = centerX + cos(angle) * (startDist + len * 0.5) + cos(perpAngle) * len * 0.15
            let cy = centerY + sin(angle) * (startDist + len * 0.5) + sin(perpAngle) * len * 0.15
            path.addQuadCurve(
                to: CGPoint(x: centerX + cos(angle) * (startDist + len), y: centerY + sin(angle) * (startDist + len)),
                control: CGPoint(x: cx, y: cy)
            )
            context.stroke(path, with: .color(color.opacity(0.85)), lineWidth: width)
        }
    }

    // MARK: Tomatoes — red diced squares clustered in the filling
    private func drawTomatoes(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 1000
        let count = 10
        let diceSize = max(3.0, rect.width * 0.055)

        for i in 0..<count {
            let angle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let dist = sqrt(pseudoRandom(seed: seed &+ i * 13, range: 1.0)) * radius * 0.85
            let x = centerX + cos(angle) * dist
            let y = centerY + sin(angle) * dist
            let sz = diceSize * (pseudoRandom(seed: seed &+ i * 19, range: 0.5) + 0.75)
            let diceRect = CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz)
            let dicePath = Path(roundedRect: diceRect, cornerRadius: sz * 0.2)
            // Red flesh
            context.fill(dicePath, with: .color(Color(red: 0.85, green: 0.15, blue: 0.1).opacity(0.9)))
            // Darker seed line suggestion
            context.stroke(dicePath, with: .color(Color(red: 0.6, green: 0.05, blue: 0.05).opacity(0.4)), lineWidth: 0.5)
        }
    }

    // MARK: Cheese — yellow-orange shred lines
    private func drawCheese(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 2000
        let count = 12
        let color = Color(red: 0.98, green: 0.78, blue: 0.1)

        for i in 0..<count {
            let angle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let dist = sqrt(pseudoRandom(seed: seed &+ i * 13, range: 1.0)) * radius * 0.9
            let x = centerX + cos(angle) * dist
            let y = centerY + sin(angle) * dist
            let len = pseudoRandom(seed: seed &+ i * 17, range: radius * 0.35) + radius * 0.1
            let shredAngle = pseudoRandom(seed: seed &+ i * 23, range: .pi)
            let endX = x + cos(shredAngle) * len
            let endY = y + sin(shredAngle) * len
            let lineWidth = pseudoRandom(seed: seed &+ i * 29, range: 2.0) + 1.5
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: endX, y: endY))
            context.stroke(path, with: .color(color.opacity(0.88)), lineWidth: lineWidth)
        }
    }

    // MARK: Sour Cream — white dollop with soft oval shape
    private func drawSourCream(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 3000

        // Offset the dollop slightly from center for realism
        let offsetX = pseudoRandom(seed: seed, range: radius * 0.3) - radius * 0.15
        let offsetY = pseudoRandom(seed: seed &+ 1, range: radius * 0.3) - radius * 0.15
        let dollR = radius * 0.42
        let dollRect = CGRect(x: centerX + offsetX - dollR, y: centerY + offsetY - dollR * 0.75,
                              width: dollR * 2, height: dollR * 1.5)
        let dollPath = Path(ellipseIn: dollRect)
        context.fill(dollPath, with: .color(Color.white.opacity(0.88)))
        // Soft edge highlight
        context.stroke(dollPath, with: .color(Color.white.opacity(0.3)), lineWidth: 2.0)
    }

    // MARK: Guacamole — muted green irregular blob
    private func drawGuacamole(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 4000
        let blobColor = Color(red: 0.42, green: 0.62, blue: 0.28)

        // Build a lumpy blob from multiple overlapping ellipses
        let blobCount = 5
        for i in 0..<blobCount {
            let angle = CGFloat(i) / CGFloat(blobCount) * .pi * 2
                + pseudoRandom(seed: seed &+ i * 7, range: 0.4)
            let dist = pseudoRandom(seed: seed &+ i * 11, range: radius * 0.22)
            let bR = radius * (pseudoRandom(seed: seed &+ i * 17, range: 0.18) + 0.22)
            let blobRect = CGRect(x: centerX + cos(angle) * dist - bR,
                                  y: centerY + sin(angle) * dist - bR * 0.85,
                                  width: bR * 2, height: bR * 1.7)
            let blobPath = Path(ellipseIn: blobRect)
            context.fill(blobPath, with: .color(blobColor.opacity(0.80)))
        }
        // Dark green texture flecks
        for i in 0..<6 {
            let angle = pseudoRandom(seed: seed &+ i * 31, range: .pi * 2)
            let dist = pseudoRandom(seed: seed &+ i * 37, range: radius * 0.3)
            let fleckSize = max(1.5, rect.width * 0.025)
            let fleckRect = CGRect(x: centerX + cos(angle) * dist - fleckSize / 2,
                                   y: centerY + sin(angle) * dist - fleckSize / 2,
                                   width: fleckSize, height: fleckSize)
            context.fill(Path(ellipseIn: fleckRect), with: .color(Color(red: 0.2, green: 0.4, blue: 0.15).opacity(0.6)))
        }
    }

    // MARK: Salsa — red-orange scattered chunky dots
    private func drawSalsa(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 5000
        let count = 14

        for i in 0..<count {
            let angle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let dist = sqrt(pseudoRandom(seed: seed &+ i * 13, range: 1.0)) * radius * 0.88
            let x = centerX + cos(angle) * dist
            let y = centerY + sin(angle) * dist
            let sz = max(2.0, rect.width * 0.04) * (pseudoRandom(seed: seed &+ i * 19, range: 0.6) + 0.7)
            let dotPath = Path(ellipseIn: CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz * 0.85))
            // Alternate between red and orange-red chunks
            let isRed = pseudoRandom(seed: seed &+ i * 23, range: 1.0) > 0.5
            let color = isRed
                ? Color(red: 0.85, green: 0.15, blue: 0.1)
                : Color(red: 0.9, green: 0.45, blue: 0.1)
            context.fill(dotPath, with: .color(color.opacity(0.82)))
        }
    }

    // MARK: Onions — diced white/purple translucent cubes
    private func drawOnions(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 6000
        let count = 12
        let cubeSize = max(2.5, rect.width * 0.042)

        for i in 0..<count {
            let angle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let dist = sqrt(pseudoRandom(seed: seed &+ i * 13, range: 1.0)) * radius * 0.85
            let x = centerX + cos(angle) * dist
            let y = centerY + sin(angle) * dist
            let sz = cubeSize * (pseudoRandom(seed: seed &+ i * 19, range: 0.5) + 0.75)
            // Slight rotation per piece for natural look
            let rotation = pseudoRandom(seed: seed &+ i * 23, range: .pi / 4) - .pi / 8
            let cubeRect = CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz * 0.85)
            var cubePath = Path(roundedRect: cubeRect, cornerRadius: sz * 0.15)
            cubePath = cubePath.applying(
                CGAffineTransform(translationX: -x, y: -y)
                    .concatenating(CGAffineTransform(rotationAngle: rotation))
                    .concatenating(CGAffineTransform(translationX: x, y: y))
            )
            // Alternate white and purple-tinged onion pieces
            let isPurple = pseudoRandom(seed: seed &+ i * 31, range: 1.0) > 0.55
            let fillColor = isPurple
                ? Color(red: 0.82, green: 0.68, blue: 0.88).opacity(0.80)
                : Color.white.opacity(0.82)
            context.fill(cubePath, with: .color(fillColor))
            context.stroke(cubePath, with: .color(Color(red: 0.6, green: 0.45, blue: 0.65).opacity(0.35)), lineWidth: 0.5)
        }
    }

    // MARK: Cilantro — dark green tiny leaf shapes
    private func drawCilantro(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 7000
        let count = 10
        let leafColor = Color(red: 0.1, green: 0.5, blue: 0.15)

        for i in 0..<count {
            let angle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let dist = sqrt(pseudoRandom(seed: seed &+ i * 13, range: 1.0)) * radius * 0.85
            let x = centerX + cos(angle) * dist
            let y = centerY + sin(angle) * dist
            let leafLen = max(3.0, rect.width * 0.045)
            let leafAngle = pseudoRandom(seed: seed &+ i * 17, range: .pi * 2)
            // Leaf: a small teardrop ellipse
            let leafRect = CGRect(x: x - leafLen * 0.25, y: y - leafLen / 2,
                                  width: leafLen * 0.5, height: leafLen)
            var path = Path(ellipseIn: leafRect)
            // Rotate around the leaf's base
            let transform = CGAffineTransform(translationX: -x, y: -y)
                .concatenating(CGAffineTransform(rotationAngle: leafAngle))
                .concatenating(CGAffineTransform(translationX: x, y: y))
            path = path.applying(transform)
            context.fill(path, with: .color(leafColor.opacity(0.80)))
            // Stem line
            var stem = Path()
            stem.move(to: CGPoint(x: x, y: y))
            stem.addLine(to: CGPoint(x: x + cos(leafAngle) * leafLen * 0.4,
                                     y: y + sin(leafAngle) * leafLen * 0.4))
            stem = stem.applying(CGAffineTransform.identity)
            context.stroke(stem, with: .color(leafColor.opacity(0.6)), lineWidth: 0.8)
        }
    }

    // MARK: Fresh Jalapeños — bright green oval slices with pale seed cavity
    private func drawFreshJalapeños(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 8000
        let count = 7
        let sliceColor = Color(red: 0.15, green: 0.72, blue: 0.22)

        for i in 0..<count {
            let angle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let dist = sqrt(pseudoRandom(seed: seed &+ i * 13, range: 1.0)) * radius * 0.80
            let x = centerX + cos(angle) * dist
            let y = centerY + sin(angle) * dist
            // Each slice is an oval rotated at a random angle
            let sliceW = max(3.0, rect.width * 0.055)
            let sliceH = sliceW * 0.65
            let sliceAngle = pseudoRandom(seed: seed &+ i * 17, range: .pi)
            let outerRect = CGRect(x: x - sliceW / 2, y: y - sliceH / 2, width: sliceW, height: sliceH)
            var outerPath = Path(ellipseIn: outerRect)
            let transform = CGAffineTransform(translationX: -x, y: -y)
                .concatenating(CGAffineTransform(rotationAngle: sliceAngle))
                .concatenating(CGAffineTransform(translationX: x, y: y))
            outerPath = outerPath.applying(transform)
            // Bright green flesh
            context.fill(outerPath, with: .color(sliceColor.opacity(0.88)))
            // Pale seed cavity in the center
            let cavityW = sliceW * 0.45, cavityH = sliceH * 0.5
            let cavityRect = CGRect(x: x - cavityW / 2, y: y - cavityH / 2, width: cavityW, height: cavityH)
            var cavityPath = Path(ellipseIn: cavityRect)
            cavityPath = cavityPath.applying(transform)
            context.fill(cavityPath, with: .color(Color(red: 0.88, green: 0.98, blue: 0.75).opacity(0.75)))
            // Dark outline
            context.stroke(outerPath, with: .color(Color(red: 0.05, green: 0.42, blue: 0.1).opacity(0.6)), lineWidth: 0.6)
        }
    }

    // MARK: Radishes — bright magenta-red round slices with white interior
    private func drawRadishes(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 10000
        let count = 8
        let skinColor = Color(red: 0.88, green: 0.12, blue: 0.28)

        for i in 0..<count {
            let angle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let dist = sqrt(pseudoRandom(seed: seed &+ i * 13, range: 1.0)) * radius * 0.82
            let x = centerX + cos(angle) * dist
            let y = centerY + sin(angle) * dist
            let sliceR = max(2.5, rect.width * 0.048)
            let outerRect = CGRect(x: x - sliceR, y: y - sliceR * 0.88, width: sliceR * 2, height: sliceR * 1.76)
            // Vivid red skin circle
            context.fill(Path(ellipseIn: outerRect), with: .color(skinColor.opacity(0.90)))
            // White interior — slightly smaller inset
            let innerR = sliceR * 0.62
            let innerRect = CGRect(x: x - innerR, y: y - innerR * 0.88, width: innerR * 2, height: innerR * 1.76)
            context.fill(Path(ellipseIn: innerRect), with: .color(Color.white.opacity(0.88)))
            // Fine red border
            context.stroke(Path(ellipseIn: outerRect), with: .color(skinColor.opacity(0.55)), lineWidth: 0.6)
        }
    }

    // MARK: Lime — bright green wedge shapes
    private func drawLime(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 11000
        let count = 5
        let rindColor = Color(red: 0.22, green: 0.68, blue: 0.18)
        let fleshColor = Color(red: 0.65, green: 0.92, blue: 0.35)

        for i in 0..<count {
            let placeAngle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let dist = pseudoRandom(seed: seed &+ i * 13, range: radius * 0.72) + radius * 0.1
            let cx = centerX + cos(placeAngle) * dist
            let cy = centerY + sin(placeAngle) * dist
            let wedgeSize = max(3.5, rect.width * 0.06)
            // Wedge: a pie-slice from a small circle, rotated randomly
            let wedgeAngle = pseudoRandom(seed: seed &+ i * 17, range: .pi * 2)
            let spreadAngle: CGFloat = .pi / 3  // 60° wedge
            var wedge = Path()
            wedge.move(to: CGPoint(x: cx, y: cy))
            wedge.addArc(center: CGPoint(x: cx, y: cy), radius: wedgeSize,
                         startAngle: .radians(wedgeAngle),
                         endAngle: .radians(wedgeAngle + spreadAngle), clockwise: false)
            wedge.closeSubpath()
            let rotTransform = CGAffineTransform(translationX: -cx, y: -cy)
                .concatenating(CGAffineTransform(rotationAngle: wedgeAngle))
                .concatenating(CGAffineTransform(translationX: cx, y: cy))
            let rotatedWedge = wedge.applying(rotTransform)
            context.fill(rotatedWedge, with: .color(fleshColor.opacity(0.85)))
            context.stroke(rotatedWedge, with: .color(rindColor.opacity(0.70)), lineWidth: 1.0)
            // Center dot
            let dotR = wedgeSize * 0.12
            context.fill(Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)),
                         with: .color(rindColor.opacity(0.5)))
        }
    }

    // MARK: Pickled Jalapeños — yellow-green ring slices with brine sheen
    private func drawPickledJalapeños(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 12000
        let count = 7
        // Pickled = more yellow-olive than fresh bright green
        let pickleColor = Color(red: 0.58, green: 0.72, blue: 0.18)

        for i in 0..<count {
            let angle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let dist = sqrt(pseudoRandom(seed: seed &+ i * 13, range: 1.0)) * radius * 0.82
            let x = centerX + cos(angle) * dist
            let y = centerY + sin(angle) * dist
            let sliceW = max(3.0, rect.width * 0.052)
            let sliceH = sliceW * 0.62
            let sliceAngle = pseudoRandom(seed: seed &+ i * 17, range: .pi)
            let outerRect = CGRect(x: x - sliceW / 2, y: y - sliceH / 2, width: sliceW, height: sliceH)
            var outerPath = Path(ellipseIn: outerRect)
            let transform = CGAffineTransform(translationX: -x, y: -y)
                .concatenating(CGAffineTransform(rotationAngle: sliceAngle))
                .concatenating(CGAffineTransform(translationX: x, y: y))
            outerPath = outerPath.applying(transform)
            // Olive-yellow flesh with slight translucency (brine effect)
            context.fill(outerPath, with: .color(pickleColor.opacity(0.82)))
            // Pale seed cavity
            let cavityW = sliceW * 0.42, cavityH = sliceH * 0.48
            let cavityRect = CGRect(x: x - cavityW / 2, y: y - cavityH / 2, width: cavityW, height: cavityH)
            var cavityPath = Path(ellipseIn: cavityRect)
            cavityPath = cavityPath.applying(transform)
            context.fill(cavityPath, with: .color(Color(red: 0.92, green: 0.96, blue: 0.72).opacity(0.70)))
            context.stroke(outerPath, with: .color(Color(red: 0.35, green: 0.48, blue: 0.08).opacity(0.55)), lineWidth: 0.6)
        }
    }

    // MARK: Hot Sauce — orange-red drizzle lines
    private func drawHotSauce(context: inout GraphicsContext, shell: ShellType, in rect: CGRect) {
        let centerX = rect.midX, centerY = rect.midY
        let radius = fillingRadius(for: shell, in: rect)
        let seed = tacoNode.id.hashValue &+ 9000
        let drizzleColor = Color(red: 0.92, green: 0.22, blue: 0.08)
        let lineCount = 3

        for i in 0..<lineCount {
            // Start from one edge of the filling, drizzle across
            let startAngle = pseudoRandom(seed: seed &+ i * 7, range: .pi * 2)
            let startX = centerX + cos(startAngle) * radius * 0.85
            let startY = centerY + sin(startAngle) * radius * 0.85
            // End on the opposite side with some variation
            let endAngle = startAngle + .pi + pseudoRandom(seed: seed &+ i * 11, range: 0.8) - 0.4
            let endX = centerX + cos(endAngle) * radius * 0.8
            let endY = centerY + sin(endAngle) * radius * 0.8
            // Control points create the drizzle wiggle
            let cp1X = centerX + pseudoRandom(seed: seed &+ i * 17, range: radius * 1.2) - radius * 0.6
            let cp1Y = centerY + pseudoRandom(seed: seed &+ i * 19, range: radius * 1.2) - radius * 0.6
            let cp2X = centerX + pseudoRandom(seed: seed &+ i * 23, range: radius * 1.2) - radius * 0.6
            let cp2Y = centerY + pseudoRandom(seed: seed &+ i * 29, range: radius * 1.2) - radius * 0.6
            var path = Path()
            path.move(to: CGPoint(x: startX, y: startY))
            path.addCurve(to: CGPoint(x: endX, y: endY),
                          control1: CGPoint(x: cp1X, y: cp1Y),
                          control2: CGPoint(x: cp2X, y: cp2Y))
            context.stroke(path, with: .color(drizzleColor.opacity(0.90)),
                           style: StrokeStyle(lineWidth: max(1.5, rect.width * 0.028), lineCap: .round))
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
