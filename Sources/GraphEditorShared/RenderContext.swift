//
//  RenderContext.swift
//  GraphEditorShared
//
//  Created by handcart on 11/19/25.
//

import SwiftUI

public struct RenderContext {
    public let effectiveCentroid: CGPoint
    public let zoomScale: CGFloat
    public let offset: CGSize        // ← was CGPoint before
    public let viewSize: CGSize
    
    public init(
        effectiveCentroid: CGPoint,
        zoomScale: CGFloat,
        offset: CGSize,              // ← now CGSize
        viewSize: CGSize
    ) {
        self.effectiveCentroid = effectiveCentroid
        self.zoomScale = zoomScale
        self.offset = offset
        self.viewSize = viewSize
    }
}
