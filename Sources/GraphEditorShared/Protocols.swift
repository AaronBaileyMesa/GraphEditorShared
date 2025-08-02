//
//  GraphStorage.swift
//  GraphEditorShared
//
//  Created by handcart on 8/1/25.
//


public protocol GraphStorage {
    func save(nodes: [Node], edges: [GraphEdge])
    func load() -> (nodes: [Node], edges: [GraphEdge])
}
