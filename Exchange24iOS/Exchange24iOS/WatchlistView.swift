//
// Copyright (c) 2026 Enjel Hutasoit
//

import MarketDataKit
import SwiftUI

struct WatchlistView: View {
    @StateObject private var viewModel: WatchlistViewModel
    
    /// Takes the pieces it needs directly rather than reading
    /// AppEnvironment via @EnvironmentObject, because @StateObject must
    /// be constructed in init — before the environment is attached to
    /// the view hierarchy. The caller (App.swift) passes them in.
    init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: WatchlistViewModel(
            marketStore: environment.marketStore,
            connectionManager: environment.connectionManager
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            statsHeader
            Divider()
            List(viewModel.rows, id: \.symbol) { tick in
                WatchlistRow(tick: tick)
            }
            .listStyle(.plain)
        }
        .navigationTitle("Watchlist")
    }
    
    private var statsHeader: some View {
        HStack {
            connectionBadge
            Spacer()
            Text("\(viewModel.ticksPerSecond)/s")
                .monospacedDigit()
            Spacer()
            Text("\(viewModel.conflatedCount) conflated")
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(viewModel.reconnectCount) reconnects")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var connectionBadge: some View {
        let (label, color): (String, Color) = {
            switch viewModel.connectionState {
            case .disconnected: return ("Disconnected", .gray)
            case .connecting: return ("Connecting…", .orange)
            case .connected: return ("Live", .green)
            case .reconnecting(let attempt): return ("Reconnecting (\(attempt))", .orange)
            }
        }()
        return Label(label, systemImage: "circle.fill")
            .foregroundStyle(color)
            .labelStyle(.titleAndIcon)
    }
}

private struct WatchlistRow: View {
    let tick: InstrumentTick
    
    var body: some View {
        HStack {
            Text(tick.symbol)
                .font(.body.monospaced())
                .frame(width: 70, alignment: .leading)
            Text("\(tick.price)")
                .monospacedDigit()
            Spacer()
            Text("vol \(tick.volume)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
