//
//  FrameView.swift
//  macOS Client
//
//  Created by Vithorio Polten on 20/04/24.
//
import Combine
import MetalKit
import SwiftUI


#if os(iOS)
/// Helper for making PreviewMetalView available in SwiftUI.
struct FrameView: UIViewRepresentable {

    let imagePublisher: AnyPublisher<CIImage?, Never>


    func makeUIView(context: Context) -> PreviewMetalView {
        return PreviewMetalView(device: MTLCreateSystemDefaultDevice(), imagePublisher:  self.imagePublisher)
    }

    func updateUIView(_ uiView: PreviewMetalView, context: Context) {

    }

}
#endif

#if os(visionOS)
/// Helper for making PreviewMetalView available in SwiftUI.
struct FrameView: UIViewRepresentable {

    let imagePublisher: AnyPublisher<CIImage?, Never>


    func makeUIView(context: Context) -> PreviewMetalView {
        return PreviewMetalView(device: MTLCreateSystemDefaultDevice(), imagePublisher:  self.imagePublisher)
    }

    func updateUIView(_ uiView: PreviewMetalView, context: Context) {

    }

}
#endif

#if os(OSX)
/// Helper for making PreviewMetalView available in SwiftUI.
struct FrameView: NSViewRepresentable {

    let imagePublisher: AnyPublisher<CIImage?, Never>


    func makeNSView(context: Context) -> PreviewMetalView {
        return PreviewMetalView(device: MTLCreateSystemDefaultDevice(), imagePublisher:  self.imagePublisher)
    }

    func updateNSView(_ nsView: PreviewMetalView, context: Context) {

    }

}
#endif


