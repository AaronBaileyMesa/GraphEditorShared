//
//  CategoryNodeTests.swift
//  GraphEditorSharedTests
//
//  Tests for CategoryNode conformance to NodeProtocol
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorShared

@available(iOS 16.0, watchOS 9.0, *)
struct CategoryNodeTests {

    @Test("CategoryNode initializes correctly")
    func testInitialization() {
        let category = CategoryNode(
            label: 1,
            position: .zero,
            name: "Groceries",
            color: .green,
            icon: "cart.fill"
        )

        #expect(category.name == "Groceries")
        #expect(category.icon == "cart.fill")
        #expect(category.isCollapsible == true)
    }

    @Test("CategoryNode can collapse and expand")
    func testCollapseExpand() {
        let category = CategoryNode(
            label: 1, position: .zero, name: "Food"
        )

        #expect(category.isExpanded == true)
        #expect(category.shouldHideChildren() == false)

        let collapsed = category.handlingTap()
        #expect(collapsed.isExpanded == false)
        #expect(collapsed.shouldHideChildren() == true)
    }

    @Test("CategoryNode manages children")
    func testChildren() {
        let category = CategoryNode(
            label: 1, position: .zero, name: "Transport"
        )

        let child1 = UUID()
        let child2 = UUID()

        let withChildren = category.with(children: [child1, child2])
        #expect(withChildren.children.count == 2)
        #expect(withChildren.children.contains(child1))
    }

    @Test("CategoryNode is Codable")
    func testCodable() throws {
        let original = CategoryNode(
            label: 5, position: CGPoint(x: 100, y: 200),
            name: "Utilities", color: .orange, icon: "bolt.fill"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CategoryNode.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.icon == original.icon)
    }
}
