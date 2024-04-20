//
//  EventView.swift
//  visionOS
//
//  Created by Saagar Jha on 12/12/23.
//

import SwiftUI

#if os(iOS) || os(visionOS)
class KeyView: UIView {
	let (keyStream, keyContinuation) = AsyncStream.makeStream(of: (Key, Bool).self)

	override var canBecomeFirstResponder: Bool {
		true
	}

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		for press in presses {
			if let _key = press.key,
				let key = Key(visionOSCode: _key.keyCode)
			{
				keyContinuation.yield((key, true))
			}
		}
	}

	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		for press in presses {
			if let _key = press.key,
				let key = Key(visionOSCode: _key.keyCode)
			{
				keyContinuation.yield((key, false))
			}
		}
	}
}
#else
class KeyView: NSView {
    let (keyStream, keyContinuation) = AsyncStream.makeStream(of: (Key, Bool).self)

    override var acceptsFirstResponder: Bool {
        true
    }
    
    fileprivate func parseEventKeys(_ event: NSEvent) -> Set<Key> {
        var keys: Set<Key> = []
        
        if let modifierKey = Key(modifierFlags: event.modifierFlags) {
            keys.insert(modifierKey)
        }
        
        if let specialKey = event.specialKey,
           let code = CGKeyCode(specialKey: specialKey),
           let key = Key(macOSCode: Int(code)) {
            keys.insert(key)
        }
        
        if let key = Key(macOSCode: Int(event.keyCode)) {
            keys.insert(key)
        }
        return keys
    }
    
    override func keyDown(with event: NSEvent) {
        parseEventKeys(event).forEach { key in
            keyContinuation.yield((key, true))
        }
    }
    
    override func keyUp(with event: NSEvent) {
        parseEventKeys(event).forEach { key in
            keyContinuation.yield((key, false))
        }
    }
}


extension CGKeyCode {
    public init?(character: String) {
        if let keyCode = Initializers.shared.characterKeys[character] {
            self = keyCode
        } else {
            return nil
        }
    }

    public init?(modifierFlag: NSEvent.ModifierFlags) {
        if let keyCode = Initializers.shared.modifierFlagKeys[modifierFlag] {
            self = keyCode
        } else {
            return nil
        }
    }
    
    public init?(specialKey: NSEvent.SpecialKey) {
        if let keyCode = Initializers.shared.specialKeys[specialKey] {
            self = keyCode
        } else {
            return nil
        }
    }
    
    private struct Initializers {
        let specialKeys: [NSEvent.SpecialKey:CGKeyCode]
        let characterKeys: [String:CGKeyCode]
        let modifierFlagKeys: [NSEvent.ModifierFlags:CGKeyCode]
        
        static let shared = Initializers()
        
        init() {
            var specialKeys = [NSEvent.SpecialKey:CGKeyCode]()
            var characterKeys = [String:CGKeyCode]()
            var modifierFlagKeys = [NSEvent.ModifierFlags:CGKeyCode]()

            for keyCode in (0..<128).map({ CGKeyCode($0) }) {
                guard let cgevent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true) else { continue }
                guard let nsevent = NSEvent(cgEvent: cgevent) else { continue }

                var hasHandledKeyCode = false
                if nsevent.type == .keyDown {
                    if let specialKey = nsevent.specialKey {
                        hasHandledKeyCode = true
                        specialKeys[specialKey] = keyCode
                    } else if let characters = nsevent.charactersIgnoringModifiers, !characters.isEmpty && characters != "\u{0010}" {
                        hasHandledKeyCode = true
                        characterKeys[characters] = keyCode
                    }
                } else if nsevent.type == .flagsChanged, let modifierFlag = nsevent.modifierFlags.first(.capsLock, .shift, .control, .option, .command, .help, .function) {
                    hasHandledKeyCode = true
                    modifierFlagKeys[modifierFlag] = keyCode
                }
                if !hasHandledKeyCode {
                    #if DEBUG
                    print("Unhandled keycode \(keyCode): \(nsevent)")
                    #endif
                }
            }
            self.specialKeys = specialKeys
            self.characterKeys = characterKeys
            self.modifierFlagKeys = modifierFlagKeys
        }
    }

}

extension NSEvent.ModifierFlags: Hashable { }

extension OptionSet {
    public func first(_ options: Self.Element ...) -> Self.Element? {
        for option in options {
            if contains(option) {
                return option
            }
        }
        return nil
    }
}
#endif

#if os(iOS) || os(visionOS)
struct EventView: UIViewRepresentable {
	let view = KeyView()
	let coordinator: Coordinator

	enum ScrollEvent {
		case began
		case changed(CGPoint)
		case ended
	}

	enum DragEvent {
		case began(CGPoint)
		case changed(CGPoint)
		case ended(CGPoint)
	}

	init() {
		coordinator = .init(view: view)
	}

	class Coordinator {
		let view: UIView
		let (scrollStream, scrollContinuation) = AsyncStream.makeStream(of: ScrollEvent.self)
		let (dragStream, dragContinuation) = AsyncStream.makeStream(of: DragEvent.self)

		init(view: UIView) {
			self.view = view
		}

		@objc
		func scroll(_ sender: UIPanGestureRecognizer) {
			switch sender.state {
				case .began:
					scrollContinuation.yield(.began)
				case .changed:
					scrollContinuation.yield(.changed(sender.translation(in: view)))
					sender.setTranslation(.zero, in: view)
				case .ended:
					scrollContinuation.yield(.ended)
				default:
					return
			}
		}

		@objc
		func pan(_ sender: UIPanGestureRecognizer) {
			var position = sender.location(in: view)
			position.x /= view.frame.width
			position.y /= view.frame.height
			switch sender.state {
				case .began:
					dragContinuation.yield(.began(position))
				case .changed:
					dragContinuation.yield(.changed(position))
				case .ended:
					dragContinuation.yield(.ended(position))
				default:
					return
			}
		}
	}

	func makeUIView(context: Context) -> some UIView {
		return view
	}

	func updateUIView(_ uiView: UIViewType, context: Context) {
	}

	func makeCoordinator() -> Coordinator {
		let scrollGestureRecognizer = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.scroll(_:)))
		scrollGestureRecognizer.allowedScrollTypesMask = .all
		scrollGestureRecognizer.allowedTouchTypes = []
		view.addGestureRecognizer(scrollGestureRecognizer)

		let dragGestureRecognizer = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.pan(_:)))
		view.addGestureRecognizer(dragGestureRecognizer)
		return coordinator
	}
}
#elseif os(macOS)
struct EventView: NSViewRepresentable {
    typealias NSViewType = NSView
    
    let view = KeyView()
    let coordinator: Coordinator

    enum ScrollEvent {
        case began
        case changed(CGPoint)
        case ended
    }

    enum DragEvent {
        case began(CGPoint)
        case changed(CGPoint)
        case ended(CGPoint)
    }

    init() {
        coordinator = .init(view: view)
    }

    class Coordinator {
        let view: NSView
        let (scrollStream, scrollContinuation) = AsyncStream.makeStream(of: ScrollEvent.self)
        let (dragStream, dragContinuation) = AsyncStream.makeStream(of: DragEvent.self)

        init(view: NSView) {
            self.view = view
        }

        @objc
        func scroll(_ sender: NSPanGestureRecognizer) {
            switch sender.state {
                case .began:
                    scrollContinuation.yield(.began)
                case .changed:
                    scrollContinuation.yield(.changed(sender.translation(in: view)))
                    sender.setTranslation(.zero, in: view)
                case .ended:
                    scrollContinuation.yield(.ended)
                default:
                    return
            }
        }

        @objc
        func pan(_ sender: NSPanGestureRecognizer) {
            var position = sender.location(in: view)
            position.x /= view.frame.width
            position.y /= view.frame.height
            switch sender.state {
                case .began:
                    dragContinuation.yield(.began(position))
                case .changed:
                    dragContinuation.yield(.changed(position))
                case .ended:
                    dragContinuation.yield(.ended(position))
                default:
                    return
            }
        }
    }

    func makeNSView(context: Context) -> NSView {
        return view
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        let scrollGestureRecognizer = NSPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.scroll(_:)))
        // scrollGestureRecognizer.allowedScrollTypesMask = .all
        scrollGestureRecognizer.allowedTouchTypes = []
        view.addGestureRecognizer(scrollGestureRecognizer)

        let dragGestureRecognizer = NSPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.pan(_:)))
        view.addGestureRecognizer(dragGestureRecognizer)
        return coordinator
    }
}
#endif

#Preview {
	EventView()
}
