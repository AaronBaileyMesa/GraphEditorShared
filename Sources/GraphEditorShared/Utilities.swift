import Foundation
import CoreGraphics

public extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        max(range.lowerBound, min(self, range.upperBound))
    }
}

public extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

public extension CGFloat {
    func rounded(to decimalPlaces: Int) -> CGFloat {
        let divisor = pow(10.0, CGFloat(decimalPlaces))
        return (self * divisor).rounded() / divisor
    }
}

public extension CGPoint {
    func normalized() -> CGPoint {
            let len = hypot(x, y)
            return len > 0 ? self / len : .zero
        }
    
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }
    
    static func -= (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs - rhs
    }
    
    static func *= (lhs: inout CGPoint, rhs: CGFloat) {
        lhs = lhs * rhs
    }
    
    static func + (lhs: CGPoint, rhs: CGSize) -> CGPoint {
        CGPoint(x: lhs.x + rhs.width, y: lhs.y + rhs.height)
    }
    
    static func += (lhs: inout CGPoint, rhs: CGSize) {
        lhs = lhs + rhs
    }
    
    var magnitude: CGFloat {
        hypot(x, y)
    }
}

public extension CGSize {
    static func / (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }
    
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    
    static func += (lhs: inout CGSize, rhs: CGSize) {
        lhs = lhs + rhs
    }
}

// Shared utility functions
public func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}

public extension Array where Element: NodeProtocol {
    func centroid() -> CGPoint? {
        guard !isEmpty else { return nil }
        let totals = reduce((x: 0.0, y: 0.0)) { acc, node in
            (x: acc.x + node.position.x, y: acc.y + node.position.y)
        }
        return CGPoint(x: totals.x / CGFloat(count), y: totals.y / CGFloat(count))
    }
}

public func centroid(of nodes: [any NodeProtocol]) -> CGPoint? {
    guard !nodes.isEmpty else { return nil }
    let totals = nodes.reduce((x: 0.0, y: 0.0)) { acc, node in
        (x: acc.x + node.position.x, y: acc.y + node.position.y)
    }
    return CGPoint(x: totals.x / CGFloat(nodes.count), y: totals.y / CGFloat(nodes.count))
}
