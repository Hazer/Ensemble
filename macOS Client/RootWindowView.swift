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

	var body: some View {
		GeometryReader { geometry in
			ZStack {
				WindowView(remote: remote, window: window)
				ForEach(children) { child in
					let width = child.frame.width / window.frame.width * geometry.size.width
					let height = child.frame.height / window.frame.height * geometry.size.height
					let x = (child.frame.minX - window.frame.minX + child.frame.width / 2) / window.frame.width * geometry.size.width / geometry.size.width
					let y = (child.frame.minY - window.frame.minY + child.frame.height / 2) / window.frame.height * geometry.size.height / geometry.size.height

                    WindowView(remote: remote, window: window)
				}
			}
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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DisplayView(remote: remote, display: display)
            }
        }
        .task {

        }
    }
}
