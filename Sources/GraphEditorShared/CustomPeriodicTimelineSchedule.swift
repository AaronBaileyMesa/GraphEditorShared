//
//  CustomPeriodicTimelineSchedule.swift
//  GraphEditorShared
//
//  Created by handcart on 12/8/25.
//

import SwiftUI

public struct CustomPeriodicTimelineSchedule: TimelineSchedule {  // Add public
    public let from: Date  // Add public (or make immutable if possible)
    public let by: TimeInterval  // Add public

    public init(from: Date = .now, by: TimeInterval) {  // Add public
        self.from = from
        self.by = by
    }

    public func entries(from startDate: Date, mode: TimelineSchedule.Mode) -> Entries {  // Add public
        Entries(current: max(startDate, self.from), normalInterval: by, mode: mode)
    }

    public struct Entries: Sequence, IteratorProtocol {  // Add public
        public typealias Element = Date  // Already public-ish, but explicit

        public var current: Date  // Add public
        public let normalInterval: TimeInterval  // Add public
        public let mode: TimelineSchedule.Mode  // Add public

        public mutating func next() -> Date? {  // Add public
            let nextValue = current
            let interval = (mode == .lowFrequency) ? 60.0 : normalInterval
            current = current.addingTimeInterval(interval)
            return nextValue
        }

        public func makeIterator() -> Entries {  // Add public
            return self
        }
    }
}
