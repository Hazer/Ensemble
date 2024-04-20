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
	let decoder = VideoDecoder()

	var body: some View {
		Group {
            if hasContent {
                GeometryReader { geometry in
                    FrameView(imagePublisher: self.previewProvider.previewCiImage).frame(minWidth: 400, minHeight: 400)
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
                for await frame in try await remote.startCasting(for: StreamTarget.window(id: window.windowID)) {
                    self.hasContent = true
                    self.previewProvider.post(frame: frame)
                }
			} catch {}
		}
	}
}

struct DisplayView: View {
    let remote: Remote
    let display: Display

    @State var hasContent: Bool = false
    
    let previewProvider = PreviewPixelBufferProvider()

    let eventView = EventView()
    let decoder = VideoDecoder()

    var body: some View {
        Group {
            if hasContent {
                GeometryReader { geometry in
                    FrameView(imagePublisher: self.previewProvider.previewCiImage).frame(minWidth: 400, minHeight: 400)
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
                for await frame in try await remote.startCasting(for: StreamTarget.display(id: display.displayID)) {
                    self.hasContent = true
                    self.previewProvider.post(frame: frame)
                }
            } catch {}
        }
    }
}
