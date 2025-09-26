//
//  CoordinateTransformer.swift
//  GraphEditorShared
//
//  Created by handcart on 9/26/25.
//

import CoreGraphics
import SwiftUI  // For GeometryProxy if enabled

/// Utility for converting between model (graph) coordinates and screen (view) coordinates.
public struct CoordinateTransformer {
    
    /// Converts a model position to screen coordinates.
    /// - Parameters:
    ///   - modelPos: The position in model space.
    ///   - effectiveCentroid: The centroid of the graph for centering.
    ///   - zoomScale: Current zoom level.
    ///   - offset: Pan offset.
    ///   - viewSize: Size of the view.
    ///   - geometry: Optional GeometryProxy for safe area adjustments (e.g., on watchOS).
    /// - Returns: Screen position.
    public static func modelToScreen(
        _ modelPos: CGPoint,
        effectiveCentroid: CGPoint,
        zoomScale: CGFloat,
        offset: CGSize,
        viewSize: CGSize
        // geometry: GeometryProxy? = nil  // Uncomment if needed for safe areas
    ) -> CGPoint {
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let relativePos = modelPos - effectiveCentroid
        let scaledPos = relativePos * zoomScale
        let screenPos = viewCenter + scaledPos + CGPoint(x: offset.width, y: offset.height)
        
        // Optional: Adjust for safe areas (symmetric to screenToModel)
        // if let geo = geometry {
        //     screenPos.x += geo.safeAreaInsets.leading
        //     screenPos.y += geo.safeAreaInsets.top
        // }
        
        #if DEBUG
        print("modelToScreen: Model \(modelPos) -> Screen \(screenPos), Zoom \(zoomScale), Offset \(offset), Centroid \(effectiveCentroid), ViewSize \(viewSize)")
        #endif
        
        return screenPos
    }
    
    /// Converts a screen position back to model coordinates.
    /// - Parameters:
    ///   - screenPos: The position in screen space.
    ///   - effectiveCentroid: The centroid of the graph for centering.
    ///   - zoomScale: Current zoom level.
    ///   - offset: Pan offset.
    ///   - viewSize: Size of the view.
    ///   - geometry: Optional GeometryProxy for safe area adjustments (e.g., on watchOS).
    /// - Returns: Model position (rounded to 3 decimals to reduce floating-point drift).
    public static func screenToModel(
        _ screenPos: CGPoint,
        effectiveCentroid: CGPoint,
        zoomScale: CGFloat,
        offset: CGSize,
        viewSize: CGSize
        // geometry: GeometryProxy? = nil  // Uncomment if needed for safe areas
    ) -> CGPoint {
        let safeZoom = max(zoomScale, 0.001)  // Prevent div-by-zero; adjust based on your minZoom
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let panOffset = CGPoint(x: offset.width, y: offset.height)
        
        let translated = screenPos - viewCenter - panOffset
        
        // Optional: Adjust for safe areas (e.g., touches missing near edges on watchOS)
        // if let geo = geometry {
        //     translated.x -= geo.safeAreaInsets.leading
        //     translated.y -= geo.safeAreaInsets.top
        // }
        
        let unscaled = translated / safeZoom
        let modelPos = effectiveCentroid + unscaled
        
        #if DEBUG
        print("screenToModel: Screen \(screenPos) -> Model \(modelPos), Zoom \(safeZoom), Offset \(panOffset), Centroid \(effectiveCentroid), ViewSize \(viewSize)")
        #endif
        
        // Round to 3 decimals to eliminate floating-point drift
        return CGPoint(x: modelPos.x.rounded(to: 3), y: modelPos.y.rounded(to: 3))
    }
}

// Extension for rounding (if not already in Utilities.swift)
private extension CGFloat {
    func rounded(to decimalPlaces: Int) -> CGFloat {
        let divisor = pow(10.0, CGFloat(decimalPlaces))
        return (self * divisor).rounded() / divisor
    }
}
