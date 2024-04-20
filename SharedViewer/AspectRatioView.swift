//
//  AspectRatioView.swift
//  Ensemble
//
//  Created by Vithorio Polten on 20/04/24.
//

import AVFoundation
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
struct AspectRatioConstrainingView: NSViewRepresentable {
    let size: CGSize

    class _View: NSView {
        var _size = CGSize.zero {
            didSet {
                window?.viewsNeedDisplay = true
            }
        }
        
        override func viewDidMoveToWindow() {
            _size = { _size }()
        }
    }

    func makeNSView(context: Context) -> _View {
        _View()
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {
        nsView._size = size
    }
}

#else
struct AspectRatioConstrainingView: UIViewRepresentable {
    let size: CGSize

    class _View: UIView {
        var _size = CGSize.zero {
            didSet {
                window?.windowScene?.requestGeometryUpdate(.Vision(size: _size, resizingRestrictions: .uniform))
            }
        }

        override func didMoveToWindow() {
            _size = { _size }()
        }
    }

    func makeUIView(context: Context) -> _View {
        _View()
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView._size = size
    }
}

#endif
