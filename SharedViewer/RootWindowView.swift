//
//  RootWindowView.swift
//  visionOS
//
//  Created by Saagar Jha on 10/21/23.
//

import AVFoundation
import SwiftUI

struct RootWindowView: View {
	let remote: Remote
	let window: Window

	@State
	var children = [Window]()

	@State
	var appIcon: Data?
    
    @State var showWindow = true

	var body: some View {
		GeometryReader { geometry in
			ZStack {
				WindowView(remote: remote, window: window)
                    .frame(minWidth: 400, minHeight: 400)
				ForEach(children) { child in
					let width = child.frame.width / window.frame.width * geometry.size.width
					let height = child.frame.height / window.frame.height * geometry.size.height
					let x = (child.frame.minX - window.frame.minX + child.frame.width / 2) / window.frame.width * geometry.size.width / geometry.size.width
					let y = (child.frame.minY - window.frame.minY + child.frame.height / 2) / window.frame.height * geometry.size.height / geometry.size.height

                    #if os(macOS)
                    
                    WindowView(remote: remote, window: child)
                        .frame(width: width, height: height)
                        .offset(x: x, y: y)
                    #elseif os(visionOS)
                        Color.clear.ornament(attachmentAnchor: .scene(.init(x: x, y: y))) {
                            WindowView(remote: remote, window: child)
                                .frame(width: width, height: height)
                        }
                    /*self.borderlessWindow(isVisible: self.$showWindow,
                                      anchor: .topLeading,
                                      windowAnchor: .topLeading,
                                                 windowOffset: CGPoint(x: x, y: y)) {
                        WindowView(remote: remote, window: child)
                            .frame(width: width, height: height)
                    }*/
                    #endif
				}
			}
#if os(macOS)
//            .borderlessWindow(isVisible: self.$showWindow,
//                              anchor: .topLeading,
//                              windowAnchor: .topLeading,
//                                         windowOffset: CGPoint(x: 0.5, y: 1 + 64 / geometry.size.height)) {
//                WindowToolbarView(title: window.title!, icon: appIcon)
//            }
#elseif os(visionOS)
            .ornament(attachmentAnchor: .scene(.init(x: 0.5, y: 1 + 64 / geometry.size.height))) {
                            WindowToolbarView(title: window.title!, icon: appIcon)
                        }
#endif
		}
        .background {
            AspectRatioConstrainingView(size: window.frame.size)
        }
		.task {
			do {
				// TODO: Scale appropriately
				appIcon = try await remote.appIcon(for: window.id, size: .init(width: 128, height: 128))
			} catch {}
			do {
				for await children in try await remote.children(of: window.id) {
					let windows = try await remote.windows
					self.children = children.compactMap { child in
						windows.first {
							$0.id == child
						}
					}
				}
			} catch {}
		}
	}
}


struct RootDisplayView: View {
    let remote: Remote
    let display: Display
    
    @State var showWindow = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DisplayView(remote: remote, display: display)
                    .frame(minWidth: 400, minHeight: 400)
            }
#if os(visionOS)
            .ornament(attachmentAnchor: .scene(.init(x: 0.5, y: 1 + 64 / geometry.size.height))) {
                            WindowToolbarView(title: display.title, icon: nil)
                        }
#endif
        }
        .task {

        }
    }
}
