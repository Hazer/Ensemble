//
//  visionOSInterface.swift
//  Shared
//
//  Created by Saagar Jha on 10/9/23.
//

import CoreMedia
import Foundation

protocol ViewerClientInterface {
	typealias M = ViewerClientMessages

	func _handshake(parameters: M.MacOSHostHandshake.Request) async throws -> M.MacOSHostHandshake.Reply
	func _displayFrame(parameters: M.DisplayFrame.Request) async throws -> M.DisplayFrame.Reply
    func _windowFrame(parameters: M.WindowFrame.Request) async throws -> M.WindowFrame.Reply
	func _childWindows(parameters: M.ChildWindows.Request) async throws -> M.ChildWindows.Reply
}

enum ViewerClientMessages {
	struct MacOSHostHandshake: Message {
		static let id = Messages.macOSHostHandshake

		struct Request: Serializable, Codable {
			let version: Int
		}

		struct Reply: Serializable, Codable {
			let version: Int
			let name: String
		}
	}
    
    struct DisplayFrame: Message {
        static let id = Messages.displayFrame

        struct Request: Serializable {
            let displayID: Display.ID
            let frame: Frame

            func encode() async throws -> Data {
                return try await displayID.uleb128 + frame.encode()
            }

            static func decode(_ data: Data) async throws -> Self {
                var data = data
                return try await self.init(displayID: .init(uleb128: &data), frame: .decode(data))
            }
        }

        typealias Reply = SerializableVoid
    }

	struct WindowFrame: Message {
		static let id = Messages.windowFrame

		struct Request: Serializable {
			let windowID: Window.ID
			let frame: Frame

			func encode() async throws -> Data {
				return try await windowID.uleb128 + frame.encode()
			}

			static func decode(_ data: Data) async throws -> Self {
				var data = data
				return try await self.init(windowID: .init(uleb128: &data), frame: .decode(data))
			}
		}

		typealias Reply = SerializableVoid
	}

	struct ChildWindows: Message {
		static let id = Messages.childWindows

		struct Request: Serializable, Codable {
			let parent: Window.ID
			let children: [Window.ID]
		}

		typealias Reply = SerializableVoid
	}
}
