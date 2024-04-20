//
//  EnsembleApp.swift
//  visionOS
//
//  Created by Saagar Jha on 10/8/23.
//

import SwiftUI

@main
struct EnsembleApp: App {
	@State
	var remote: Remote?

	// This needs to be available "immedidately" because when the binding
	// updates it will consult this list, and @State will have a stale value.
	class _State {
        var viewables = [StreamTarget: Shareable]()
	}
	let state = _State()

    var body: some Scene {
        WindowGroup("Window", id: "window", for: StreamTarget.self) { $target in
            if let remote {
                let selected = Binding(
                    get: {
                        $target.wrappedValue.flatMap {
                            state.viewables[$0]
                        }
                    },
                    set: {
                        if let viewable = $0 {
                            switch viewable {
                            case .display(let display):
                                let id = StreamTarget.display(id: display.id)
                                state.viewables[id] = viewable
                                $target.wrappedValue = id
                            case .window(let window):
                                let id = StreamTarget.window(id: window.id)
                                state.viewables[id] = viewable
                                $target.wrappedValue = id
                            }
                        }
                    })

                //ContentView(remote: remote, selectedWindow: selectedWindow)
                ContentViewAll(remote: remote, selected: selected)
            } else {
                ConnectionView(remote: $remote)
            }
        }
        #if os(visionOS)
        .windowStyle(.plain)
        #else
        .windowStyle(.titleBar)
        #endif
        .windowResizability(.contentSize)
    }
}
