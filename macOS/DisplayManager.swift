//
//  DisplayManager.swift
//  macOS
//
//  Created by Vithorio Polten on 20/04/24.
//

import Foundation
import AVFoundation
import ScreenCaptureKit

actor DisplayManager {
    var displays = [CGDirectDisplayID: SCDisplay]()

    func updateDisplays() async throws {
        displays.removeAll()
        
        for display in try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false).displays {
            displays[display.displayID] = display
        }
    }

    func _lookupDisplay(byID id: CGDirectDisplayID) async throws -> SCDisplay? {
        guard let display = displays[id] else {
            try await updateDisplays()
            return displays[id]
        }
        return display
    }

    func lookupDisplay(byID id: CGDirectDisplayID) async throws -> SCDisplay? {
        try await _lookupDisplay(byID: id)
    }

    var allDisplays: [SCDisplay] {
        get async throws {
            try await updateDisplays()
            return displays.values.map { $0 }
        }
    }
}
