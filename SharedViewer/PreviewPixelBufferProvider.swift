//
//  PreviewPixelBufferProvider.swift
//  macOS Client
//
//  Created by Vithorio Polten on 20/04/24.
//

import SwiftUI
import Combine

class PreviewPixelBufferProvider: ObservableObject {
    @Published var previewPixelBuffer: CVPixelBuffer?
    
    lazy var previewCiImage = mapToCIImage(pixelBufferPublisher: $previewPixelBuffer.eraseToAnyPublisher())
    
    private func mapToCIImage(
        pixelBufferPublisher: AnyPublisher<CVPixelBuffer?, Never>
    ) ->  AnyPublisher<CIImage?, Never> {
        return pixelBufferPublisher
            // transform the pixel buffer into an `CIImage`...
            .map { $0.flatMap({ CIImage(cvPixelBuffer: $0) }) }
            .eraseToAnyPublisher()
    }
    
    func post(newBuffer: CVPixelBuffer?) {
        self.previewPixelBuffer = newBuffer
    }
    
    
    func post(frame: Frame) {
        self.previewPixelBuffer = frame.frame.0
    }
}
