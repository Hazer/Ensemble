//
//  FramePreviewView.swift
//  macOS Client
//
//  Created by Vithorio Polten on 20/04/24.
//

import SwiftUI

struct FramePreviewView: View {
    let remote: Remote
    let window: Window

    @Binding
    var selectedWindow: Window?

//    @State
//    var preview: Frame?
    
    @State var hasContent: Bool = false
    
    let previewProvider = PreviewPixelBufferProvider()

    var body: some View {
        Button(action: {
            selectedWindow = window
        }) {
            VStack(alignment: .leading) {
                let size = macOSInterface.M.WindowPreview.previewSize
                Group {
                    if hasContent {
                        FrameView(imagePublisher: self.previewProvider.previewCiImage).frame(minWidth: 400, minHeight: 400)
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
//                self.preview = preview
                self.hasContent = true
                self.previewProvider.post(frame: preview)
                // try await Task.sleep(for: .seconds(1))
                // }
            } catch {}
        }
    }
}
