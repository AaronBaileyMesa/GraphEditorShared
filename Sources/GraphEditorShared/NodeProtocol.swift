//
//  NodeProtocol.swift
//  GraphEditorShared
//
//  Created by handcart on 8/5/25.
//


import SwiftUI
import Foundation

public protocol NodeProtocol: Identifiable, Equatable, Codable where ID == NodeID {
    var id: NodeID { get }
    var label: Int { get }  // Non-mutating for now; mutations handled via model updates
    var position: CGPoint { get set }
    var velocity: CGPoint { get set }
    var radius: CGFloat { get set }
    
    // Hook for custom rendering (returns a View; passed context like zoomScale and selection state)
    func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView
    
    // Hook for handling interactions (e.g., tap); returns a mutated version of self
    func handlingTap() -> Self
    
    // Hook for visibility (determines if this node should be rendered)
    var isVisible: Bool { get }
    
    // Hook for child-hiding logic (true if descendants via outgoing edges should be hidden)
    func shouldHideChildren() -> Bool
}

extension NodeProtocol {
    // Default implementations (can be overridden)
    public func renderView(zoomScale: CGFloat, isSelected: Bool) -> AnyView {
        let scaledRadius = radius * zoomScale
        let borderWidth: CGFloat = isSelected ? 4 * zoomScale : 0
        let borderRadius = scaledRadius + borderWidth / 2
        
        return AnyView(
            ZStack {
                Circle()
                    .fill(Color.red)  // Default color from GraphCanvasView
                    .frame(width: 2 * scaledRadius, height: 2 * scaledRadius)
                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: borderWidth)
                        .frame(width: 2 * borderRadius, height: 2 * borderRadius)
                }
                Text("\(label)")
                    .foregroundColor(.white)
                    .font(.system(size: UIFontMetrics.default.scaledValue(for: 12) * zoomScale))
            }
        )
    }
    
    public func handlingTap() -> Self {
        return self  // Default: No change
    }
    
    public var isVisible: Bool {
        true
    }
    
    public func shouldHideChildren() -> Bool {
        false
    }
}