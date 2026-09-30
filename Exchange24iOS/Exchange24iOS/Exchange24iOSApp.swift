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
                OrdersPlaceholderView()
            }
            .tabItem { Label("Orders", systemImage: "list.bullet.rectangle") }
        }
    }
}

/// Placeholder for this commit only: the Orders screen with sabotage
/// controls and the "what the server actually has" panel is the next
/// commit. Keeps the restart demo control reachable in the meantime.
private struct OrdersPlaceholderView: View {
    @EnvironmentObject private var environment: AppEnvironment
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Orders screen lands next commit")
                .foregroundStyle(.secondary)
            Button("Simulate app restart") {
                environment.simulateRestart()
            }
        }
        .navigationTitle("Orders")
    }
}
