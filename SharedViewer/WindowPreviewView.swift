//
//  WindowPreviewView.swift
//  visionOS
//
//  Created by Saagar Jha on 10/10/23.
//

import SwiftUI

struct WindowPreviewView: View {
	let remote: Remote
	let window: Window

	@Binding
	var selectedViewable: Shareable?

    @State var hasContent: Bool = false
    
    let previewProvider = PreviewPixelBufferProvider()

	var body: some View {
		Button(action: {
            selectedViewable = Shareable.window(value: window)
		}) {
			VStack(alignment: .leading) {
				let size = macOSHostInterface.M.WindowPreview.previewSize
				Group {
                    if hasContent {
                        FrameView(imagePublisher: self.previewProvider.previewCiImage)
					} else {
						ProgressView {
							Text("Loading Preview…")
						}
					}
				}.frame(width: size.width, height: size.height)
				Text(window.app)
					.font(.title)
					.lineLimit(1)
				Text(window.title!)
					.lineLimit(1)
			}
		}
		.buttonBorderShape(.roundedRectangle)
		.task {
			do {
				// while true {
				guard let preview = try await remote.windowPreview(for: window.id) else {
					return
				}
                self.hasContent = true
                self.previewProvider.post(frame: preview)
				// try await Task.sleep(for: .seconds(1))
				// }
			} catch {}
		}
	}
}

struct DisplayPreviewView: View {
    let remote: Remote
    let display: Display

    @Binding
    var selectedViewable: Shareable?

    @State var hasContent: Bool = false
    
    let previewProvider = PreviewPixelBufferProvider()

    var body: some View {
        Button(action: {
            selectedViewable = Shareable.display(value: display)
        }) {
            VStack(alignment: .leading) {
                let size = macOSHostInterface.M.DisplayPreview.previewSize
                Group {
                    if hasContent {
                        FrameView(imagePublisher: self.previewProvider.previewCiImage)//.frame(minWidth: 400, minHeight: 400)
                    } else {
                        ProgressView {
                            Text("Loading Preview…")
                        }
                    }
                }.frame(width: size.width, height: size.height)
                Text(display.title)
                    .font(.title)
                    .lineLimit(1)
                Text("\(display.width)x\(display.height)")
                    .lineLimit(1)
            }
        }
        .buttonBorderShape(.roundedRectangle)
        .task {
            do {
                // while true {
                guard let preview = try await remote.displayPreview(for: display.id) else {
                    return
                }
                self.hasContent = true
                self.previewProvider.post(frame: preview)
                // try await Task.sleep(for: .seconds(1))
                // }
            } catch {}
        }
    }
}
