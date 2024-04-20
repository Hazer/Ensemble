//
//  WindowView.swift
//  visionOS
//
//  Created by Saagar Jha on 10/10/23.
//

import SwiftUI

struct WindowView: View {
	let remote: Remote
	let window: Window

    @State var hasContent: Bool = false
    
    let previewProvider = PreviewPixelBufferProvider()

	let eventView = EventView()

	var body: some View {
		Group {
            if hasContent {
                GeometryReader { geometry in
                    FrameView(imagePublisher: self.previewProvider.previewCiImage)
                        .overlay {
                            eventView
                                .task {
                                    do {
                                        for await event in eventView.coordinator.scrollStream {
                                            switch event {
                                                case .began:
                                                    _ = try await remote._scrollBegan(parameters: .init(windowID: window.windowID))
                                                case .changed(let translation):
                                                    _ = try await remote._scrollChanged(parameters: .init(windowID: window.windowID, x: translation.x, y: translation.y))
                                                case .ended:
                                                    _ = try await remote._scrollEnded(parameters: .init(windowID: window.windowID))
                                            }
                                        }
                                    } catch {}
                                }
                                .task {
                                    do {
                                        for await event in eventView.coordinator.dragStream {
                                            switch event {
                                                case .began(let translation):
                                                    _ = try await remote._dragBegan(parameters: .init(windowID: window.windowID, x: translation.x, y: translation.y))
                                                case .changed(let translation):
                                                    _ = try await remote._dragChanged(parameters: .init(windowID: window.windowID, x: translation.x, y: translation.y))
                                                case .ended(let translation):
                                                    _ = try await remote._dragEnded(parameters: .init(windowID: window.windowID, x: translation.x, y: translation.y))
                                            }
                                        }
                                    } catch {}
                                }
                                .task {
                                    do {
                                        for await (key, down) in eventView.view.keyStream {
                                            _ = try await remote._typed(parameters: .init(windowID: window.windowID, key: key, down: down))
                                        }
                                    } catch {}
                                }
                        }
                        .onTapGesture { location in
                            eventView.view.becomeFirstResponder()
                            Task {
                                _ = try await remote._clicked(parameters: .init(windowID: window.windowID, x: location.x / geometry.size.width, y: location.y / geometry.size.height))
                            }
                        }
                        .onContinuousHover(coordinateSpace: .local) {
                            switch $0 {
                                case .active(let location):
                                    Task {
                                        do {
                                            _ = try await remote._mouseMoved(parameters: .init(windowID: window.windowID, x: location.x / geometry.size.width, y: location.y / geometry.size.height))
                                        } catch {}
                                    }
                                default:
                                    break
                            }
                        }
                        .onAppear {
                            eventView.view.becomeFirstResponder()
                        }
                }
            } else {
                Text("Loading… \(self.window.app)")
            }
		}
		.task {
			do {
                for await frame in try await remote.startCasting(for: StreamTarget.window(windowID: window.windowID)) {
                    self.hasContent = true
                    self.previewProvider.post(frame: frame)
                }
			} catch {
                print("Failed starting window \(error)")
            }
		}
	}
}

struct DisplayView: View {
    let remote: Remote
    let display: Display

    @State var hasContent: Bool = false
    
    let previewProvider = PreviewPixelBufferProvider()

    let eventView = EventView()

    var body: some View {
        Group {
            if hasContent {
                GeometryReader { geometry in
                    FrameView(imagePublisher: self.previewProvider.previewCiImage)
                        .onAppear {
                            eventView.view.becomeFirstResponder()
                        }
                }
            } else {
                Text("Loading…")
            }
        }
        .task {
            do {
                for await frame in try await remote.startCasting(for: StreamTarget.display(displayID: display.displayID)) {
                    self.hasContent = true
                    self.previewProvider.post(frame: frame)
                }
            } catch {
                print("Failed starting streaming: \(error)")
            }
        }
    }
}
