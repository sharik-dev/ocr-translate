// Put this in a shared utilities file or at the top of SettingsViewModel.swift
import Foundation

extension Array {
    mutating func remove(atOffsets offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            remove(at: offset)
        }
    }

    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        // Extract the elements to move
        let moving = offsets.sorted().map { self[$0] }

        // Remove them from the original array (from highest index to lowest)
        for offset in offsets.sorted(by: >) {
            remove(at: offset)
        }

        // Adjust destination if we removed items before it
        var adjustedDestination = destination
        for offset in offsets {
            if offset < destination { adjustedDestination -= 1 }
        }

        insert(contentsOf: moving, at: adjustedDestination)
    }
}
