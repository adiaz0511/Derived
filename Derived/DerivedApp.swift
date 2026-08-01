//
//  DerivedApp.swift
//  Derived
//
//  Created by Arturo Diaz on 7/31/26.
//

import SwiftUI

@main
struct DerivedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
