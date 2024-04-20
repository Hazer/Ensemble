//
//  WindowPickerView.swift
//  visionOS
//
//  Created by Saagar Jha on 10/10/23.
//

import SwiftUI

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
                                } else if case let .display(display) = $0 {
                                    true
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
                }.frame(minWidth: 450, maxWidth: .infinity)
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
                        } else if case let .display(display) = $0 {
                            true
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
