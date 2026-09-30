//
// Copyright (c) 2026 Enjel Hutasoit
//

import Combine
import Foundation
import MarketDataKit

/// Bridges two Kit AsyncStreams into @Published state a SwiftUI view can
/// bind to directly. This is the only place in the Watchlist feature that
/// touches `await` — the view itself stays plain SwiftUI.
@MainActor
final class WatchlistViewModel: ObservableObject {
    @Published private(set) var rows: [InstrumentTick] = []
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var reconnectCount = 0
    @Published private(set) var ticksPerSecond = 0
    @Published private(set) var conflatedCount = 0
    
    private let marketStore: MarketDataStore
    private let connectionManager: ConnectionManager
    private let flushInterval: Duration
    private var tasks: [Task<Void, Never>] = []
    
    init(
        marketStore: MarketDataStore,
        connectionManager: ConnectionManager,
        flushInterval: Duration = .milliseconds(Int64(250))
    ) {
        self.marketStore = marketStore
        self.connectionManager = connectionManager
        self.flushInterval = flushInterval
        start()
    }
    
    deinit {
        for task in tasks { task.cancel() }
    }
    
    private func start() {
        var state: [String: InstrumentTick] = [:]
        var ticksInWindow = 0
        var windowStart = Date()
        
        let marketStore = self.marketStore
        let interval = self.flushInterval
        
        tasks.append(Task {
            // Stream must be retained and consumed for as long as this
            // view model lives: dropping it deallocates the AsyncStream,
            // which fires onTermination and stops MarketDataStore's
            // flush loop for everyone, not just this screen.
            let stream = await marketStore.updates(every: interval)
            
            for await batch in stream {
                for tick in batch {
                    state[tick.symbol] = tick
                }
                rows = state.values.sorted { $0.symbol < $1.symbol }
                
                ticksInWindow += batch.count
                let now = Date()
                if now.timeIntervalSince(windowStart) >= 1 {
                    ticksPerSecond = ticksInWindow
                    ticksInWindow = 0
                    windowStart = now
                }
                
                conflatedCount = await marketStore.conflatedUpdateCount()
            }
        })
        
        let connectionManager = self.connectionManager
        tasks.append(Task {
            let states = await connectionManager.connectionStates()
            for await newState in states {
                connectionState = newState
                if case .reconnecting(let attempt) = newState, attempt == 1 {
                    reconnectCount += 1
                }
            }
        })
    }
}
