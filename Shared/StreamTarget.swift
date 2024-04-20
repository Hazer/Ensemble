//
//  StreamTarget.swift
//  Ensemble
//
//  Created by Vithorio Polten on 20/04/24.
//
import AVFoundation

enum StreamTarget: Codable, Hashable {
    case window(windowID: CGWindowID)
    case display(displayID: CGDirectDisplayID)
}
