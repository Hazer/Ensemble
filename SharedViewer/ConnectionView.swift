//
//  ConnectionView.swift
//  visionOS
//
//  Created by Saagar Jha on 10/9/23.
//

import AppleConnect
import Network
import SwiftUI

let service = "_\(Bundle.main.bounjourServiceName)._tcp"

struct ConnectionView: View {
	@Binding
	var remote: Remote?

	@State
	var endpoints: [NWEndpoint] = []

	var body: some View {
		NavigationSplitView(
			sidebar: {
				let icons = ["macbook", "macstudio", "macpro.gen3", "desktopcomputer"]
#if os(macOS)
				let gridSize = 2
#else
                let gridSize = 9
                #endif

				VStack(spacing: 20) {
					ForEach(Array(1...gridSize), id: \.self) { row in
						HStack(spacing: 20) {
							ForEach(Array(1...gridSize), id: \.self) { column in
								Image(systemName: icons[(row * gridSize + column) % icons.count])
									.resizable()
									.aspectRatio(contentMode: .fit)
									.frame(width: 100, height: 100)
							}
						}
					}
				}
				.rotationEffect(.radians(0.5))
				.toolbar(.hidden)
			},
			detail: {
				VStack {
					List(endpoints.indices, id: \.self) {
						let endpoint = endpoints[$0]
						switch endpoint {
							case .service(let name, _, _, _):
								Button(name) {
									Task {
										do {
											let connection = try await Connection(endpoint: endpoint, key: Data())
											var remote = Remote(connection: connection)
											if try await remote.handshake() {
												self.remote = remote
											}
										} catch {
                                            print("failed conn \(error)")
										}
									}
								}
							default:
								fatalError()
						}
                    }
                        
                    Text("To get started, open \(Bundle.main.name) on your Mac and select it from the list.")
						.padding()
				}
				.navigationTitle("Available Macs")
			}
		)
		.task {
			do {
				for try await endpoints in Connection.endpoints(forServiceType: service) {
					self.endpoints = endpoints
				}
			} catch {}
		}
	}
}

#Preview {
	ConnectionView(remote: .constant(nil))
}
