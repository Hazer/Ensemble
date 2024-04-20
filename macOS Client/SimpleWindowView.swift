//
//  SimpleWindowView.swift
//  macOS Client
//
//  Created by Vithorio Polten on 20/04/24.
//

import SwiftUI
import Combine

struct StreamingView: View {
    let remote: Remote
    let window: Window

//    @State
//    var frame: Frame?
    
    @State var hasContent: Bool = false
    
    let previewProvider = PreviewPixelBufferProvider()

    let eventView = EventView()
    let decoder = VideoDecoder()

    var body: some View {
        Group {
            if hasContent {
                GeometryReader { geometry in
                    FrameView(imagePublisher: self.previewProvider.previewCiImage).frame(minWidth: 400, minHeight: 400)
//                    let (frame, mask) = frame.frame
//                    let image = CIImage(cvImageBuffer: frame)
//                    let cgImage = CIContext().createCGImage(image, from: image.extent)!
//                    Image(nsImage: NSImage(cgImage: cgImage, size: .init(width: cgImage.width, height: cgImage.height)))
//                        .resizable().frame(minWidth: 400, minHeight: 400)
//                        .onAppear {
////                            renderer.begin()
//                            eventView.view.becomeFirstResponder()
//                        }
                }
            } else {
                Text("Loading…")
            }
        }
        .task {
            do {
                for await frame in try await remote.startCasting(for: window.windowID) {
//                    self.frame = frame
                    self.hasContent = true
                    self.previewProvider.post(frame: frame)
                }
            } catch {}
        }
    }
    
}
