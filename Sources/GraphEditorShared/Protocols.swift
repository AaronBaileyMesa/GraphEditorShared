//
//  GraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//


@available(iOS 13.0, *)
public protocol GraphStorage {
    func save(nodes: [Node], edges: [GraphEdge]) throws  
    func load() -> (nodes: [Node], edges: [GraphEdge])
}
