//
//  Exchange24iOSApp.swift
//  Exchange24iOS
//
//  Created by Enjel Hutasoit on 29/09/26.
//

import SwiftUI

@main
struct Exchange24iOSApp: App {
    var body: some Scene {
        WindowGroup {
            WrickingCheckView()
        }
    }
}

/// Placeholder root view for this commit only: proves the composition
/// root builds and the background loops run, before the Watchlist and
/// Orders screens replace it. Intentionally not reactive yet — polling
/// a couple of actor values on a timer is fine for a throwaway debug
/// view; the real screens (next commits) bridge AsyncStreams properly.
struct WrickingCheckView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var symbolCount = 0
    @State private var conflatedCount = 0
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Exchange24 — composition root wired")
                .font(.headline)
            Text("\(symbolCount) instruments tracked")
            Text("\(conflatedCount) ticks conflated so far")
            Button("Simulate app restart") {
                environment.simulateRestart()
            }
        }
        .padding()
        .onReceive(timer) { _ in
            Task {
                symbolCount = await environment.marketStore.currentState().count
                conflatedCount = await environment.marketStore.conflatedUpdateCount()
            }
        }
    }
}
