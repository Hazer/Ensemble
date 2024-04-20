//
//  WindowPickerView.swift
//  visionOS
//
//  Created by Saagar Jha on 10/10/23.
//

import SwiftUI

struct WindowPickerView: View {
	let remote: Remote

	@State
	var windows: [Window]?
	@State
	var filter: String = ""

	@Binding
	var selectedViewable: Shareable?

	var body: some View {
		NavigationStack {
			if let windows {
				ScrollView {
					LazyVGrid(
						columns: [GridItem(), GridItem()],
						spacing: 20,
						content: {
							let filteredWindows = windows.filter {
								filter.isEmpty || $0.app.localizedStandardContains(filter) || $0.title?.localizedStandardContains(filter) ?? false
							}
							ForEach(filteredWindows) { window in
								WindowPreviewView(remote: remote, window: window, selectedViewable: $selectedViewable)
							}
						}
					)
					.padding(20)
				}
				.navigationTitle("Select a window.")
				.searchable(text: $filter)
			} else {
				Text("Loading windows…")
			}
		}
		.task {
			do {
				while true {
					windows = try await remote.windows.filter {
						!($0.title?.isEmpty ?? true) && $0.windowLayer == 0 /* NSWindow.Level.normal */
					}.sorted {
						$0.windowID < $1.windowID
					}
					try await Task.sleep(for: .seconds(1))
				}
			} catch {}
		}
	}
}

struct TargetPickerView: View {
    let remote: Remote

    @State
    var viewables: [Shareable]?
    
    @State
    var filter: String = ""

    @Binding
    var selected: Shareable?

    var body: some View {
        NavigationStack {
            if let viewables {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(), GridItem()],
                        spacing: 20,
                        content: {
                            let filteredViewables = viewables.filter {
                                if case let .window(window) = $0 {
                                    filter.isEmpty || window.app.localizedStandardContains(filter) || window.title?.localizedStandardContains(filter) ?? false
                                } else {
                                    false
                                }
                            }
                            ForEach(filteredViewables) { viewable in
                                switch viewable {
                                case .window(let window):
                                    WindowPreviewView(remote: remote, window: window, selectedViewable: $selected)
                                case .display(let display):
                                    DisplayPreviewView(remote: remote, display: display, selectedViewable: $selected)
                                }
                            }
                        }
                    )
                    .padding(20)
                }
                .navigationTitle("Select a window.")
                .searchable(text: $filter)
            } else {
                Text("Loading windows…")
            }
        }
        .task {
            do {
                while true {
                    viewables = try await remote.shareables.filter {
                        if case let .window(window) = $0 {
                            !(window.title?.isEmpty ?? true) && window.windowLayer == 0 /* NSWindow.Level.normal */
                        } else {
                            false
                        }
                    }.sorted {
                        if case let .window(window) = $0, case let .window(otherWindow) = $1 {
                            $0.id < $1.id
                        } else if case let .display(display) = $0, case let .window(otherDisplay) = $1 {
                            $0.id < $1.id
                        } else {
                            if case .display(_) = $0 {
                                $0.id > $1.id
                            } else {
                                $0.id < $1.id
                            }
                        }
                    }
                    try await Task.sleep(for: .seconds(1))
                }
            } catch {}
        }
    }
}
