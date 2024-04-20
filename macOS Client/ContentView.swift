//
//  ContentView.swift
//  visionOS
//
//  Created by Saagar Jha on 10/8/23.
//

import AppleConnect
import SwiftUI

struct ContentViewAll: View {
    var remote: Remote

    @Binding
    var selected: Shareable?

    var body: some View {
        Group {
            switch selected {
            case .window(let selectedWindow):
                RootWindowView(remote: remote, window: selectedWindow)
            case .display(let selectedDisplay):
                RootDisplayView(remote: remote, display: selectedDisplay)
            case nil:
                TargetPickerView(remote: remote, selected: $selected)
            }
        }
    }
}
