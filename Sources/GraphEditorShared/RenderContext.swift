//
//  RenderContext.swift
//  GraphEditorShared
//
//  Created by handcart on 11/19/25.
//


// In GraphEditorShared/Sources/GraphEditorShared/RenderContext.swift  (new file)
import SwiftUI

public struct RenderContext {
    public let effectiveCentroid: CGPoint
    public let zoomScale: CGFloat
    public let offset: CGSize
    public let viewSize: CGSize
    
    public init(effectiveCentroid: CGPoint, zoomScale: CGFloat, offset: CGSize, viewSize: CGSize) {
        self.effectiveCentroid = effectiveCentroid
        self.zoomScale = zoomScale
        self.offset = offset
        self.viewSize = viewSize
    }
}

