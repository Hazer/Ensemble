//
//  Remote.swift
//  macOS
//
//  Created by Saagar Jha on 10/9/23.
//

import AppleConnect
import CoreGraphics
import CoreMedia

struct Remote: ViewerClientInterface {
	let connection: Multiplexer
	var name: String!

	init(connection: Connection) {
		let local = Local()
		self.connection = Multiplexer(connection: connection, localInterface: local)
		local.remote = self
	}

	mutating func handshake() async throws -> Bool {
		let handshake = try await _handshake(parameters: .init(version: Messages.version))
		guard handshake.version == Messages.version else {
			return false
		}
		name = handshake.name
		return true
	}

	func _handshake(parameters: M.MacOSHostHandshake.Request) async throws -> M.MacOSHostHandshake.Reply {
		try await M.MacOSHostHandshake.send(parameters, through: connection)
	}
    
    func displayFrame(forDisplayID displayID: CGDirectDisplayID, frame: Frame) async throws {
        _ = try await _displayFrame(parameters: .init(displayID: displayID, frame: frame))
    }

    func _displayFrame(parameters: M.DisplayFrame.Request) async throws -> M.DisplayFrame.Reply {
        try await M.DisplayFrame.send(parameters, through: connection)
    }

	func windowFrame(forWindowID windowID: CGWindowID, frame: Frame) async throws {
		_ = try await _windowFrame(parameters: .init(windowID: windowID, frame: frame))
	}

	func _windowFrame(parameters: M.WindowFrame.Request) async throws -> M.WindowFrame.Reply {
		try await M.WindowFrame.send(parameters, through: connection)
	}

	func childWindows(parent: CGWindowID, children: [CGWindowID]) async throws {
		_ = try await _childWindows(parameters: .init(parent: parent, children: children))
	}

	func _childWindows(parameters: M.ChildWindows.Request) async throws -> M.ChildWindows.Reply {
		try await M.ChildWindows.send(parameters, through: connection)
	}
}
