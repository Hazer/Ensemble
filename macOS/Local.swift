//
//  Local.swift
//  macOS
//
//  Created by Saagar Jha on 10/9/23.
//

import AVFoundation
import Accelerate
import AppKit
import CryptoKit
import Foundation
import SystemConfiguration

class Local: LocalInterface, macOSHostInterface {
	var remote: Remote!

	let screenRecorder = ScreenRecorder()
	let eventDispatcher = EventDispatcher()
	let windowManager = WindowManager()
    let displayManager = DisplayManager()

	struct Mask {
		let mask: vImage.PixelBuffer<vImage.Planar8>
		let hash: SHA256Digest
		var acknowledged: Bool
	}

	actor Masks {
		var masks = [StreamTarget: Mask]()

		func unmask(_ frame: inout Frame, for target: StreamTarget) {
			switch masks[target] {
				case let .some(mask):
					let same = mask.mask.withUnsafeBufferPointer { oldMask in
						frame.mask.withUnsafeBufferPointer { newMask in
							memcmp(oldMask.baseAddress, newMask.baseAddress, min(oldMask.count, newMask.count)) == 0
						}
					}
					if !same {
						fallthrough
					}
				case nil:
					frame.mask.withUnsafeBufferPointer {
						masks[target] = Mask(mask: frame.mask, hash: SHA256.hash(data: $0), acknowledged: false)
					}
			}

			if let mask = masks[target], mask.acknowledged {
				frame.skipMask = true
			}
		}

		func remove(for target: StreamTarget) {
			masks.removeValue(forKey: target)
		}

		func acknowledge(hash: Data, for target: StreamTarget) {
			var mask = masks[target]!
			if Data(mask.hash) == hash {
				mask.acknowledged = true
			}
			masks[target] = mask
		}
	}
	let masks = Masks()

	func handle(message: Messages, data: Data) async throws -> Data? {
		switch message {
			case .viewerClientHandshake:
				return try await _handshake(parameters: .decode(data)).encode()
            case .shareables:
                return try await _shareables(parameters: .decode(data)).encode()
            case .displays:
                return try await _displays(parameters: .decode(data)).encode()
			case .windows:
				return try await _windows(parameters: .decode(data)).encode()
			case .windowPreview:
				return try await _windowPreview(parameters: .decode(data)).encode()
            case .displayPreview:
                return try await _displayPreview(parameters: .decode(data)).encode()
			case .startCasting:
				return try await _startCasting(parameters: .decode(data)).encode()
			case .stopCasting:
				return try await _stopCasting(parameters: .decode(data)).encode()
			case .windowMask:
				return try await _windowMask(parameters: .decode(data)).encode()
			case .startWatchingForChildWindows:
				return try await _startWatchingForChildWindows(parameters: .decode(data)).encode()
			case .stopWatchingForChildWindows:
				return try await _stopWatchingForChildWindows(parameters: .decode(data)).encode()
			case .mouseMoved:
				return try await _mouseMoved(parameters: .decode(data)).encode()
			case .clicked:
				return try await _clicked(parameters: .decode(data)).encode()
			case .scrollBegan:
				return try await _scrollBegan(parameters: .decode(data)).encode()
			case .scrollChanged:
				return try await _scrollChanged(parameters: .decode(data)).encode()
			case .scrollEnded:
				return try await _scrollEnded(parameters: .decode(data)).encode()
			case .dragBegan:
				return try await _dragBegan(parameters: .decode(data)).encode()
			case .dragChanged:
				return try await _dragChanged(parameters: .decode(data)).encode()
			case .dragEnded:
				return try await _dragEnded(parameters: .decode(data)).encode()
			case .typed:
				return try await _typed(parameters: .decode(data)).encode()
			case .appIcon:
				return try await _appIcon(parameters: .decode(data)).encode()
			default:
				return nil
		}
	}

	func _handshake(parameters: M.ViewerClientHandshake.Request) async throws -> M.ViewerClientHandshake.Reply {
		return .init(version: Messages.version, name: SCDynamicStoreCopyComputerName(nil, nil)! as String)
	}

	func _windows(parameters: M.Windows.Request) async throws -> M.Windows.Reply {
		return try await .init(
			windows: windowManager.allWindows.compactMap {
				guard let application = $0.owningApplication?.applicationName,
					$0.isOnScreen
				else {
					return nil
				}
				return Window(windowID: $0.windowID, title: $0.title, app: application, frame: $0.frame, windowLayer: $0.windowLayer)
			})
	}
    
    func _displays(parameters: M.Displays.Request) async throws -> M.Displays.Reply {
        return try await .init(
            displays: displayManager.allDisplays.compactMap {
                return Display(displayID: $0.displayID, width: $0.width, height: $0.height, frame: $0.frame)
            })
    }
    
    func _shareables(parameters: M.Shareables.Request) async throws -> M.Shareables.Reply {
        var shareables: [Shareable] = try await windowManager.allWindows.compactMap {
            guard let application = $0.owningApplication?.applicationName,
                $0.isOnScreen
            else {
                return nil
            }
            return Shareable.window(
                value: Window(windowID: $0.windowID, title: $0.title, app: application, frame: $0.frame, windowLayer: $0.windowLayer)
            )
        }
        
        shareables += try await displayManager.allDisplays.compactMap {
            return Shareable.display(
                value: Display(displayID: $0.displayID, width: $0.width, height: $0.height, frame: $0.frame)
            )
        }
        
        return .init(shareables: shareables)
    }

	func _windowPreview(parameters: M.WindowPreview.Request) async throws -> M.WindowPreview.Reply {
		guard let window = try await windowManager.lookupWindow(byID: parameters.windowID),
			window.isOnScreen,
			let screenshot = try await screenRecorder.screenshot(window: window, size: M.WindowPreview.previewSize)
		else {
			return nil
		}

		return try await Frame(frame: screenshot)
	}
    
    func _displayPreview(parameters: M.DisplayPreview.Request) async throws -> M.DisplayPreview.Reply {
        guard let display = try await displayManager.lookupDisplay(byID: parameters.displayID),
            let screenshot = try await screenRecorder.screenshot(display: display, size: M.DisplayPreview.previewSize)
        else {
            return nil
        }

        return try await Frame(frame: screenshot)
    }

	func _startCasting(parameters: M.StartCasting.Request) async throws -> M.StartCasting.Reply {
        switch parameters.target {
        case .window(let windowID):
            let window = try await windowManager.lookupWindow(byID: windowID)!
            let stream = try await screenRecorder.stream(window: window)
            
            Task {
                for await frame in stream where frame.imageBuffer != nil {
                    Task {
                        var frame = try await Frame(frame: frame)
                        await masks.unmask(&frame, for: parameters.target)
                        
                        try await remote.windowFrame(forWindowID: windowID, frame: frame)
                    }
                }
            }
        case .display(let displayID):
            let display = try await displayManager.lookupDisplay(byID: displayID)!
            let stream = try await screenRecorder.stream(display: display)
            
            Task {
                for await frame in stream where frame.imageBuffer != nil {
                    Task {
                        var frame = try await Frame(frame: frame)
                        await masks.unmask(&frame, for: parameters.target)
                        
                        try await remote.displayFrame(forDisplayID: displayID, frame: frame)
                    }
                }
            }
        }
		
		return .init()
	}

	func _stopCasting(parameters: M.StopCasting.Request) async throws -> M.StopCasting.Reply {
		await screenRecorder.stopStream(for: parameters.target)
		await masks.remove(for: parameters.target)
		return .init()
	}

	func _windowMask(parameters: M.WindowMask.Request) async throws -> M.WindowMask.Reply {
        await masks.acknowledge(hash: parameters.hash, for: StreamTarget.window(windowID: parameters.windowID))
		return .init()
	}

	var childObservers = [CGWindowID: Task<Void, Error>]()

	func _startWatchingForChildWindows(parameters: M.StartWatchingForChildWindows.Request) async throws -> M.StartWatchingForChildWindows.Reply {
		childObservers[parameters.windowID] = Task {
			for try await children in try await windowManager.childrenOfWindow(identifiedBy: parameters.windowID) {
				try await remote.childWindows(parent: parameters.windowID, children: children)
			}
		}
		return .init()
	}

	func _stopWatchingForChildWindows(parameters: M.StopWatchingForChildWindows.Request) async throws -> M.StopWatchingForChildWindows.Reply {
		childObservers.removeValue(forKey: parameters.windowID)!.cancel()
		return .init()
	}

	func _mouseMoved(parameters: M.MouseMoved.Request) async throws -> M.MouseMoved.Reply {
		let window = try await windowManager.lookupWindow(byID: parameters.windowID)!
		await eventDispatcher.injectMouseMoved(to: .init(x: window.frame.minX + window.frame.width * parameters.x, y: window.frame.minY + window.frame.height * parameters.y))

		return .init()
	}

	func _clicked(parameters: M.Clicked.Request) async throws -> M.Clicked.Reply {
		let window = try await windowManager.lookupWindow(byID: parameters.windowID)!
		await windowManager.activateWindow(identifiedBy: parameters.windowID, force: true)
		await eventDispatcher.injectClick(at: .init(x: window.frame.minX + window.frame.width * parameters.x, y: window.frame.minY + window.frame.height * parameters.y))
		return .init()
	}

	func _scrollBegan(parameters: M.ScrollBegan.Request) async throws -> M.ScrollBegan.Reply {
		await windowManager.activateWindow(identifiedBy: parameters.windowID)
		await eventDispatcher.injectScrollBegan()

		return .init()
	}

	func _scrollChanged(parameters: M.ScrollChanged.Request) async throws -> M.ScrollChanged.Reply {
		await windowManager.activateWindow(identifiedBy: parameters.windowID)
		await eventDispatcher.injectScrollChanged(translationX: parameters.x, translationY: parameters.y)

		return .init()
	}

	func _scrollEnded(parameters: M.ScrollEnded.Request) async throws -> M.ScrollEnded.Reply {
		await windowManager.activateWindow(identifiedBy: parameters.windowID)
		await eventDispatcher.injectScrollEnded()

		return .init()
	}

	func _dragBegan(parameters: M.DragBegan.Request) async throws -> M.DragBegan.Reply {
		let window = try await windowManager.lookupWindow(byID: parameters.windowID)!
		await windowManager.activateWindow(identifiedBy: parameters.windowID)
		await eventDispatcher.injectDragBegan(at: .init(x: window.frame.minX + window.frame.width * parameters.x, y: window.frame.minY + window.frame.height * parameters.y))

		return .init()
	}

	func _dragChanged(parameters: M.DragChanged.Request) async throws -> M.DragChanged.Reply {
		let window = try await windowManager.lookupWindow(byID: parameters.windowID)!
		await windowManager.activateWindow(identifiedBy: parameters.windowID)
		await eventDispatcher.injectDragChanged(to: .init(x: window.frame.minX + window.frame.width * parameters.x, y: window.frame.minY + window.frame.height * parameters.y))

		return .init()
	}

	func _dragEnded(parameters: M.DragEnded.Request) async throws -> M.DragEnded.Reply {
		let window = try await windowManager.lookupWindow(byID: parameters.windowID)!
		await eventDispatcher.injectDragEnded(at: .init(x: window.frame.minX + window.frame.width * parameters.x, y: window.frame.minY + window.frame.height * parameters.y))

		return .init()
	}

	func _typed(parameters: M.Typed.Request) async throws -> M.Typed.Reply {
		await windowManager.activateWindow(identifiedBy: parameters.windowID)
		await eventDispatcher.injectKey(key: parameters.key, down: parameters.down)

		return .init()
	}

	func _appIcon(parameters: M.AppIcon.Request) async throws -> M.AppIcon.Reply {
		let icon = try await windowManager.lookupApplication(forWindowID: parameters.windowID)!.icon!
		let size = AVMakeRect(aspectRatio: icon.size, insideRect: .init(origin: .zero, size: .init(width: parameters.size.width, height: parameters.size.height))).size
		let representation = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!

		NSGraphicsContext.saveGraphicsState()
		NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
		icon.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: icon.size), operation: .copy, fraction: 1)
		NSGraphicsContext.restoreGraphicsState()

		return .init(image: representation.representation(using: .png, properties: [:])!)
	}
}
