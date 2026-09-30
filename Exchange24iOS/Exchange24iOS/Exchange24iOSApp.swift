//
//  Exchange24iOSApp.swift
//  Exchange24iOS
//
//  Created by Enjel Hutasoit on 29/09/26.
//

import SwiftUI

@main
struct Exchange24iOSApp: App {
    @StateObject private var environment = AppEnvironment()
    
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(environment)
            // Forces a full teardown/rebuild of every screen and its
            // view model whenever AppEnvironment.generation changes
            // (bumped by simulateRestart()). Without this, screens
            // already on-screen would keep holding @StateObject view
            // models built at init time, still bound to the actor
            // instances from before the simulated "kill".
                .id(environment.generation)
        }
    }
}

private struct RootTabView: View {
    @EnvironmentObject private var environment: AppEnvironment
    
    var body: some View {
        TabView {
            NavigationStack {
                WatchlistView(environment: environment)
            }
            .tabItem { Label("Watchlist", systemImage: "chart.line.uptrend.xyaxis") }
            
            NavigationStack {
                OrdersView(environment: environment)
            }
            .tabItem { Label("Orders", systemImage: "list.bullet.rectangle") }
        }
    }
}
