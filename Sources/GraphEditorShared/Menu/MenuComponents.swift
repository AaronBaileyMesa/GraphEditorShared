// Sources/GraphEditorShared/Menu/MenuComponents.swift

import SwiftUI
import Foundation

/// Represents a section in a node's context menu
@available(iOS 16.0, watchOS 9.0, *)
public struct MenuSection {
    public let title: String?
    public let items: [MenuItem]

    public init(title: String?, items: [MenuItem]) {
        self.title = title
        self.items = items
    }

    public static func info(_ items: [MenuItem]) -> MenuSection {
        MenuSection(title: nil, items: items)
    }

    public static func actions(_ items: [MenuItem]) -> MenuSection {
        MenuSection(title: "Actions", items: items)
    }

    public static func properties(_ items: [MenuItem]) -> MenuSection {
        MenuSection(title: "Properties", items: items)
    }
}

/// Individual menu item
@available(iOS 16.0, watchOS 9.0, *)
public enum MenuItem {
    case text(String)
    case label(String, String)  // key, value
    case button(String, action: () -> Void)
    case buttonWithIcon(String, icon: String, color: Color, action: () -> Void)
    case toggle(String, binding: Binding<Bool>)
    case picker(String, selection: Binding<String>, options: [String])
    case navigation(String, destination: AnyView)
    case sheet(String, icon: String?, content: AnyView)
    case divider
}

/// Context provided to menu builders
@available(iOS 16.0, watchOS 9.0, *)
public struct MenuContext {
    public let dismiss: () -> Void

    public init(dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
    }
}
