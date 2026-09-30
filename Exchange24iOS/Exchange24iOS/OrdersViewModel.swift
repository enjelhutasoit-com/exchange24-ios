//
// Copyright (c) 2026 Enjel Hutasoit
//

import Foundation
import OrderKit
import OrderKitMocks

@MainActor
final class OrdersViewModel: ObservableObject {
    @Published private(set) var orders: [Order] = []
    @Published private(set) var serverOrders: [ClientOrderID: ServerOrderStatus] = [:]
    @Published var symbol: String = "BBCA"
    @Published var quantity: String = "100"
    @Published var price: String = "9000"
    @Published var lastError: String?
    
    /// Exposed directly so the view can wire sabotage buttons
    /// (dropNextRequest, loseNextSubmitResponse, ...) without this view
    /// model needing a pass-through method for every single one.
    let exchange: SimulatedExchange
    
    private let orderMachine: OrderStateMachine
    private var orderIDs: [ClientOrderID] = []
    private var pollTask: Task<Void, Never>?
    
    init(orderMachine: OrderStateMachine, exchange: SimulatedExchange) {
        self.orderMachine = orderMachine
        self.exchange = exchange
        startPolling()
    }
    
    deinit {
        pollTask?.cancel()
    }
    
    func placeOrder() {
        guard let qty = Int(quantity), qty > 0 else {
            lastError = "Quantity must be a positive whole number."
            return
        }
        guard let priceValue = Decimal(string: price), priceValue > 0 else {
            lastError = "Price must be a positive number."
            return
        }
        lastError = nil
        
        let symbol = self.symbol
        let orderMachine = self.orderMachine
        Task {
            let order = await orderMachine.create(symbol: symbol, quantity: qty, price: priceValue)
            orderIDs.append(order.id)
            await orderMachine.submit(order.id)
            await refreshNow()
        }
    }
    
    func cancel(_ order: Order) {
        let orderMachine = self.orderMachine
        Task {
            await orderMachine.cancel(order.id)
            await refreshNow()
        }
    }
    
    func reconcile(_ order: Order) {
        let orderMachine = self.orderMachine
        Task {
            await orderMachine.reconcile(order.id)
            await refreshNow()
        }
    }
    
    /// Demo-only polling, not an AsyncStream subscription. Two reasons:
    /// OrderStateMachine has no change stream yet (a real one would add
    /// one), and SimulatedExchange.updates() is already claimed by
    /// AppEnvironment's fill-forwarding loop — subscribing to it again
    /// here would silently steal that continuation, the same
    /// single-subscriber limitation already noted on
    /// ConnectionManager.connectionStates(). 300ms is fine for a demo.
    private func startPolling() {
        pollTask = Task {
            while !Task.isCancelled {
                await refreshNow()
                try? await Task.sleep(for: .milliseconds(Int64(300)))
            }
        }
    }
    
    private func refreshNow() async {
        var result: [Order] = []
        for id in orderIDs {
            if let order = await orderMachine.order(id) {
                result.append(order)
            }
        }
        orders = result
        serverOrders = await exchange.serverOrders()
    }
}
