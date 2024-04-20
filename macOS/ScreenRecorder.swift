//
//  ScreenRecorder.swift
//  macOS
//
//  Created by Saagar Jha on 10/21/23.
//

import AVFoundation
import ScreenCaptureKit

actor ScreenRecorder {
	static func streamConfiguration() -> SCStreamConfiguration {
		let configuration = SCStreamConfiguration()
		configuration.pixelFormat = kCVPixelFormatType_32BGRA
		return configuration
	}

	func screenshot(window: SCWindow, size: CGSize) async throws -> CMSampleBuffer? {
		let filter = SCContentFilter(desktopIndependentWindow: window)
		let configuration = Self.streamConfiguration()
		let size = AVMakeRect(aspectRatio: window.frame.size, insideRect: CGRect(origin: .zero, size: size)).size
		configuration.width = Int(size.width)
		configuration.height = Int(size.height)
		configuration.captureResolution = .nominal
		configuration.showsCursor = false
		return try await SCScreenshotManager.captureSampleBuffer(contentFilter: filter, configuration: configuration)
	}
    
    func screenshot(display: SCDisplay, size: CGSize) async throws -> CMSampleBuffer? {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = Self.streamConfiguration()
        let size = AVMakeRect(aspectRatio: display.frame.size, insideRect: CGRect(origin: .zero, size: size)).size
        configuration.width = Int(size.width)
        configuration.height = Int(size.height)
        configuration.captureResolution = .nominal
        configuration.showsCursor = false
        return try await SCScreenshotManager.captureSampleBuffer(contentFilter: filter, configuration: configuration)
    }

	struct Stream {
		class Output: NSObject, SCStreamOutput {
			let continuation: AsyncStream<CMSampleBuffer>.Continuation

			init(continuation: AsyncStream<CMSampleBuffer>.Continuation) {
				self.continuation = continuation
			}

			func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
				continuation.yield(sampleBuffer)
			}
		}

		let (frames, continuation) = AsyncStream.makeStream(of: CMSampleBuffer.self, bufferingPolicy: .bufferingNewest(2))
		let output: Output
		let stream: SCStream

		init(window: SCWindow) async throws {
			let filter = SCContentFilter(desktopIndependentWindow: window)

			let configuration = ScreenRecorder.streamConfiguration()
			configuration.width = Int(window.frame.width * CGFloat(filter.pointPixelScale))
			configuration.height = Int(window.frame.height * CGFloat(filter.pointPixelScale))
			if #available(macOS 14.2, *) {
				configuration.includeChildWindows = SLSCopyAssociatedWindows == nil
			}
			configuration.showsCursor = false

			stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
			output = Output(continuation: continuation)
			try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: nil)
			try await stream.startCapture()
		}
        
        init(display: SCDisplay) async throws {
            let mode: RecordMode = .h264_sRGB
            let displayID = display.displayID
            let displaySize = CGDisplayBounds(displayID).size

            // The number of physical pixels that represent a logic point on screen, currently 2 for MacBook Pro retina displays
            let displayScaleFactor: Int
            if let mode = CGDisplayCopyDisplayMode(displayID) {
                displayScaleFactor = mode.pixelWidth / mode.width
            } else {
                displayScaleFactor = 1
            }

            // AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
            // Downsize to fit a larger display back into in 4K
            let videoSize = downsizedVideoSize(source: displaySize, scaleFactor: displayScaleFactor, mode: mode)

            // MARK: SCStream setup

            // Create a filter for the specified display
            let sharableContent = try await SCShareableContent.current
            guard let display = sharableContent.displays.first(where: { $0.displayID == displayID }) else {
                throw RecordingError("Can't find display with ID \(displayID) in sharable content")
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])

            let configuration = SCStreamConfiguration()

            // Increase the depth of the frame queue to ensure high fps at the expense of increasing
            // the memory footprint of WindowServer.
            configuration.queueDepth = 6 // 4 minimum, or it becomes very stuttery
            
            // Make sure to take displayScaleFactor into account
            // otherwise, image is scaled up and gets blurry
            configuration.width = Int(displaySize.width) * displayScaleFactor
            configuration.height = Int(displaySize.height) * displayScaleFactor

            // Set pixel format an color space, see CVPixelBuffer.h
            switch mode {
            case .h264_sRGB:
                configuration.pixelFormat = kCVPixelFormatType_32BGRA // 'BGRA'
                configuration.colorSpaceName = CGColorSpace.sRGB
            case .hevc_displayP3:
                configuration.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked // 'l10r'
                configuration.colorSpaceName = CGColorSpace.displayP3
    //        case .hevc_displayP3_HDR:
    //            configuration.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked // 'l10r'
    //            configuration.colorSpaceName = CGColorSpace.displayP3
            }

            // Create SCStream and add local StreamOutput object to receive samples
            stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            output = Output(continuation: continuation)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: nil)
            try await stream.startCapture()
        }

		func stop() async {
			// This will throw an error if the window doesn't exist anymore
			try? await stream.stopCapture()
		}
	}

	var streams = [StreamTarget: Stream]()

	func stream(window: SCWindow) async throws -> AsyncStream<CMSampleBuffer> {
        let stream = try await Stream(window: window)
        streams[StreamTarget.window(windowID: window.windowID)] = stream
		return stream.frames
	}
    
    func stream(display: SCDisplay) async throws -> AsyncStream<CMSampleBuffer> {
        let stream = try await Stream(display: display)
        streams[StreamTarget.display(displayID: display.displayID)] = stream
        return stream.frames
    }

	func stopStream(for target: StreamTarget) async {
		await streams.removeValue(forKey: target)?.stop()
	}
}


enum RecordMode {
    case h264_sRGB
    case hevc_displayP3

    // I haven't gotten HDR recording working yet.
    // The commented out code is my best attempt, but still results in "blown out whites".
    //
    // Any tips are welcome!
    // - Tom
//    case hevc_displayP3_HDR
}


// AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
private func downsizedVideoSize(source: CGSize, scaleFactor: Int, mode: RecordMode) -> (width: Int, height: Int) {
    let maxSize = mode.maxSize

    let w = source.width * Double(scaleFactor)
    let h = source.height * Double(scaleFactor)
    let r = max(w / maxSize.width, h / maxSize.height)

    return r > 1
        ? (width: Int(w / r), height: Int(h / r))
        : (width: Int(w), height: Int(h))
}

struct RecordingError: Error, CustomDebugStringConvertible {
    var debugDescription: String
    init(_ debugDescription: String) { self.debugDescription = debugDescription }
}

// Extension properties for values that differ per record mode
extension RecordMode {
    var preset: AVOutputSettingsPreset {
        switch self {
        case .h264_sRGB: return .preset3840x2160
        case .hevc_displayP3: return .hevc7680x4320
//        case .hevc_displayP3_HDR: return .hevc7680x4320
        }
    }

    var maxSize: CGSize {
        switch self {
        case .h264_sRGB: return CGSize(width: 4096, height: 2304)
        case .hevc_displayP3: return CGSize(width: 7680, height: 4320)
//        case .hevc_displayP3_HDR: return CGSize(width: 7680, height: 4320)
        }
    }

    var videoCodecType: CMFormatDescription.MediaSubType {
        switch self {
        case .h264_sRGB: return .h264
        case .hevc_displayP3: return .hevc
//        case .hevc_displayP3_HDR: return .hevc
        }
    }

    var videoColorProperties: NSDictionary {
        switch self {
        case .h264_sRGB:
            return [
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ]
        case .hevc_displayP3:
            return [
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ]
//        case .hevc_displayP3_HDR:
//            return [
//                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
//                AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
//                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
//            ]
        }
    }

    var videoProfileLevel: CFString? {
        switch self {
        case .h264_sRGB:
            return nil
        case .hevc_displayP3:
            return nil
//        case .hevc_displayP3_HDR:
//            return kVTProfileLevel_HEVC_Main10_AutoLevel
        }
    }
}
