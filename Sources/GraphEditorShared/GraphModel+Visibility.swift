//
//  GraphModel+Visibility.swift
//  GraphEditorShared
//
//  Created by handcart on 9/19/25.
//

import Foundation
import os

extension GraphModel {    
    public func visibleNodes() -> [any NodeProtocol] {
        let hidden = hiddenNodeIDs
        return nodes.map { $0.unwrapped }.filter { !hidden.contains($0.id) }
    }
    
    public func visibleEdges() -> [GraphEdge] {
        let hidden = hiddenNodeIDs
        return edges.filter { !hidden.contains($0.from) && !hidden.contains($0.target) }
    }
}
