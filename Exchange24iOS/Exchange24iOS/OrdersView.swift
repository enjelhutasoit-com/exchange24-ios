//
// Copyright (c) 2026 Enjel Hutasoit
//

import OrderKit
import OrderKitMocks
import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: OrdersViewModel
    
    init(environment: AppEnvironment) {
        _viewModel = StateObject(wrappedValue: OrdersViewModel(
            orderMachine: environment.orderMachine,
            exchange: environment.exchange
        ))
    }
    
    var body: some View {
        List {
            orderFormSection
            sabotageSection
            ordersSection
            serverTruthSection
            restartSection
        }
        .navigationTitle("Orders")
    }
    
    private var orderFormSection: some View {
        Section("New order") {
            TextField("Symbol", text: $viewModel.symbol)
                .textInputAutocapitalization(.characters)
            TextField("Quantity", text: $viewModel.quantity)
                .keyboardType(.numberPad)
            TextField("Price", text: $viewModel.price)
                .keyboardType(.decimalPad)
            
            if let error = viewModel.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            Button("Submit order") {
                viewModel.placeOrder()
            }
        }
    }
    
    /// One-shot sabotage: each button arms exactly the failure it names
    /// for the very next relevant network call, exercising the same
    /// scenarios OrderStateMachineTests covers, but visibly.
    private var sabotageSection: some View {
        Section("Sabotage (applies to the next matching call)") {
            Button("Drop next request before it reaches the server") {
                Task { await viewModel.exchange.dropNextRequest() }
            }
            Button("Lose next submit response (server still applies it)") {
                Task { await viewModel.exchange.loseNextSubmitResponse() }
            }
            Button("Lose next cancel response (server still applies it)") {
                Task { await viewModel.exchange.loseNextCancelResponse() }
            }
            Button("Fail next reconciliation query") {
                Task { await viewModel.exchange.failNextStatusQuery() }
            }
            Button("Reject next new order") {
                Task { await viewModel.exchange.rejectNext("insufficient buying power") }
            }
        }
    }
    
    private var ordersSection: some View {
        Section("Your orders (client-side belief)") {
            if viewModel.orders.isEmpty {
                Text("No orders yet.").foregroundStyle(.secondary)
            }
            ForEach(Array(viewModel.orders.enumerated()), id: \.offset) { _, order in
                OrderRow(
                    order: order,
                    onCancel: { viewModel.cancel(order) },
                    onReconcile: { viewModel.reconcile(order) }
                )
            }
        }
    }
    
    /// The point of the whole screen: shows what the server actually has
    /// recorded, next to what the client believes above. After "lose next
    /// submit response", the client shows timeoutUnknown while this panel
    /// already shows the order as working — the exact gap idempotency and
    /// reconciliation exist to close.
    private var serverTruthSection: some View {
        Section("What the server actually has") {
            if viewModel.serverOrders.isEmpty {
                Text("No orders on the server yet.").foregroundStyle(.secondary)
            }
            ForEach(Array(viewModel.serverOrders.keys), id: \.self) { id in
                if let status = viewModel.serverOrders[id] {
                    HStack {
                        Text(shortID(id))
                            .font(.caption.monospaced())
                        Spacer()
                        Text(describe(status))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private var restartSection: some View {
        Section {
            Button("Simulate app restart", role: .destructive) {
                environment.simulateRestart()
            }
        } footer: {
            Text("Rebuilds the connection, market data and order state machine from nothing, but keeps orders in the durable store — then reconciles every one that wasn't finished.")
        }
    }
    
    private func shortID(_ id: ClientOrderID) -> String {
        String(id.value.uuidString.prefix(8))
    }
    
    private func describe(_ status: ServerOrderStatus) -> String {
        switch status {
        case .notFound: return "not found"
        case .working: return "working"
        case .partiallyFilled(let qty): return "partially filled (\(qty))"
        case .filled: return "filled"
        case .rejected(let reason): return "rejected: \(reason)"
        case .cancelled: return "cancelled"
        }
    }
}

private struct OrderRow: View {
    let order: Order
    let onCancel: () -> Void
    let onReconcile: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(order.symbol)  \(order.quantity) @ \(order.price)")
                    .font(.subheadline)
                Spacer()
                stateBadge
            }
            HStack {
                Button("Reconcile", action: onReconcile)
                    .font(.caption)
                if canCancel {
                    Button("Cancel", role: .destructive, action: onCancel)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private var canCancel: Bool {
        switch order.state {
        case .acknowledged, .partiallyFilled:
            return true
        default:
            return false
        }
    }
    
    private var stateBadge: some View {
        let (label, color) = describeState(order.state)
        return Text(label)
            .font(.caption.bold())
            .foregroundStyle(color)
    }
    
    private func describeState(_ state: OrderState) -> (String, Color) {
        switch state {
        case .draft: return ("draft", .gray)
        case .submitting: return ("submitting…", .orange)
        case .acknowledged: return ("acknowledged", .blue)
        case .partiallyFilled(let qty): return ("partial (\(qty))", .blue)
        case .filled: return ("filled", .green)
        case .rejected: return ("rejected", .red)
        case .timeoutUnknown: return ("unknown (timeout)", .orange)
        case .reconciling: return ("reconciling…", .orange)
        case .notPlaced: return ("not placed", .gray)
        case .cancelPending: return ("cancel pending…", .orange)
        case .cancelled: return ("cancelled", .gray)
        }
    }
}
