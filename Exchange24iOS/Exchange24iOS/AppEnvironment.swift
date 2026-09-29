//
// Copyright (c) 2026 Enjel Hutasoit
//

import Combine
import Foundation
import MarketDataKit
import MarketDataKitMocks
import OrderKit
import OrderKitMocks

/// Wires every "Kit" piece together for the demo app. This is the one
/// place that knows concrete types (SimulatedMarketTransport,
/// SimulatedExchange); every screen downstream only sees the Kit
/// protocols and actors, same as a real app talking to a real backend
/// would.
///
/// Auto-resync is event-driven, not polled: the loop below already sees
/// every MergeOutcome as it forwards events into MarketDataStore, so a
/// detected gap triggers sendSnapshot() immediately, with no separate
/// timer checking `needsResync` on an interval.
@MainActor
public final class AppEnvironment: ObservableObject {
    public let marketTransport: SimulatedMarketTransport
    public let exchange: SimulatedExchange
    
    public private(set) var connectionManager: ConnectionManager
    public private(set) var marketStore: MarketDataStore
    public private(set) var orderMachine: OrderStateMachine
    
    /// Kept outside recreation so simulateRestart() can rebuild every
    /// in-memory piece while preserving what a real app's on-disk
    /// persistence would have survived.
    private let orderStore: InMemoryOrderStore
    
    private var tasks: [Task<Void, Never>] = []
    
    public init() {
        let transport = SimulatedMarketTransport()
        let exchange = SimulatedExchange()
        let orderStore = InMemoryOrderStore()
        
        self.marketTransport = transport
        self.exchange = exchange
        self.orderStore = orderStore
        self.connectionManager = ConnectionManager(transport: transport)
        self.marketStore = MarketDataStore()
        self.orderMachine = OrderStateMachine(gateway: exchange, store: orderStore)
        
        startBackgroundLoops()
    }
    
    /// Simulates the app being killed and relaunched: everything is
    /// rebuilt from nothing except orderStore, mirroring what real
    /// disk-backed persistence would keep. Market data has no such
    /// durability requirement in this domain — a fresh connection with a
    /// fresh snapshot is the correct behavior, not a limitation.
    public func simulateRestart() {
        for task in tasks { task.cancel() }
        tasks.removeAll()
        
        connectionManager = ConnectionManager(transport: marketTransport)
        marketStore = MarketDataStore()
        orderMachine = OrderStateMachine(gateway: exchange, store: orderStore)
        
        startBackgroundLoops()
        Task { [orderMachine] in
            await orderMachine.recoverAll()
        }
    }
    
    private func startBackgroundLoops() {
        let connectionManager = self.connectionManager
        let marketStore = self.marketStore
        let transport = self.marketTransport
        
        tasks.append(Task {
            for await event in await connectionManager.events() {
                let outcome = await marketStore.ingest(event)
                if case .gapDetected = outcome {
                    transport.sendSnapshot()
                }
            }
        })
        
        let exchange = self.exchange
        let orderMachine = self.orderMachine
        
        tasks.append(Task {
            for await update in await exchange.updates() {
                await orderMachine.handleServerUpdate(update.id, update.status)
            }
        })
    }
}
