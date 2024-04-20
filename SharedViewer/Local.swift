//
//  Local.swift
//  visionOS
//
//  Created by Saagar Jha on 10/9/23.
//

import CoreVideo
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

class Local: LocalInterface, ViewerClientInterface {
	var remote: Remote!

	var streams = [StreamTarget: AsyncStream<Frame>.Continuation]()
	var children = [Window.ID: AsyncStream<[Window.ID]>.Continuation]()
	actor Masks {
		var masks = [StreamTarget: CVImageBuffer]()

		func mask(_ frame: inout Frame, for target: StreamTarget) {
			if let mask = masks[target] {
				frame.augmentWithMask(mask)
			}
			masks[target] = frame.frame.1
		}
	}
	let masks = Masks()

	func handle(message: Messages, data: Data) async throws -> Data? {
		switch message {
			case .macOSHostHandshake:
				return try await _handshake(parameters: .decode(data)).encode()
            case .displayFrame:
                return try await _displayFrame(parameters: .decode(data)).encode()
			case .windowFrame:
				return try await _windowFrame(parameters: .decode(data)).encode()
			case .childWindows:
				return try await _childWindows(parameters: .decode(data)).encode()
			default:
				return nil
		}
	}

	func _handshake(parameters: M.MacOSHostHandshake.Request) async throws -> M.MacOSHostHandshake.Reply {
        #if os(iOS) || os(visionOS)
            return await .init(version: Messages.version, name: UIDevice.current.name)
        #else
            return .init(version: Messages.version, name: Host.current().name ?? "macOS Viewer")
        #endif
	}
    
    func _displayFrame(parameters: M.DisplayFrame.Request) async throws -> M.DisplayFrame.Reply {
        let target = StreamTarget.display(displayID: parameters.displayID)
        let stream = streams[target]!
        let frame = parameters.frame
        stream.yield(frame)
        return .init()
    }

	func _windowFrame(parameters: M.WindowFrame.Request) async throws -> M.WindowFrame.Reply {
        let target = StreamTarget.window(windowID: parameters.windowID)
        let stream = streams[target]!
		var frame = parameters.frame
		await masks.mask(&frame, for: target)

		if let maskHash = frame.maskHash {
			Task {
				try await remote._windowMask(parameters: .init(windowID: parameters.windowID, hash: Data(maskHash)))
			}
		}

		stream.yield(frame)
		return .init()
	}

	func _childWindows(parameters: M.ChildWindows.Request) async throws -> M.ChildWindows.Reply {
		let stream = children[parameters.parent]!
		stream.yield(parameters.children)
		return .init()
	}
}
