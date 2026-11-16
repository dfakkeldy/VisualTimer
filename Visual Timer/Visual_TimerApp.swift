//
//  Visual_TimerApp.swift
//  Visual Timer
//
//  Created by Dan Fakkeldy on 2026-05-17.
//

import SwiftUI

@main
struct Visual_TimerApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                // One ink canvas for every tab and sheet, independent of system appearance.
                .preferredColorScheme(.dark)
        }
    }
}
