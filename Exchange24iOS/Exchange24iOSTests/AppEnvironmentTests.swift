//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import Exchange24iOS

final class AppEnvironmentTests: XCTestCase {
    @MainActor
    func testSimulateRestartRebuildsTransientComponentsAndKeepsSimulators() {
        let environment = AppEnvironment()
        let originalTransport = environment.marketTransport
        let originalExchange = environment.exchange
        let originalConnectionManager = environment.connectionManager
        let originalMarketStore = environment.marketStore
        let originalOrderMachine = environment.orderMachine

        environment.simulateRestart()

        // The simulators represent external services and should survive a relaunch.
        XCTAssertTrue(environment.marketTransport === originalTransport)
        XCTAssertTrue(environment.exchange === originalExchange)

        // These components hold transient state and should be rebuilt.
        XCTAssertFalse(environment.connectionManager === originalConnectionManager)
        XCTAssertFalse(environment.marketStore === originalMarketStore)
        XCTAssertFalse(environment.orderMachine === originalOrderMachine)
    }

    @MainActor
    func testRepeatedRestartRebuildsTransientComponentsEachTime() {
        let environment = AppEnvironment()

        environment.simulateRestart()
        let firstRestartManager = environment.connectionManager
        let firstRestartStore = environment.marketStore
        let firstRestartOrderMachine = environment.orderMachine

        environment.simulateRestart()

        // Guards against later restarts accidentally retaining stale actors.
        XCTAssertFalse(environment.connectionManager === firstRestartManager)
        XCTAssertFalse(environment.marketStore === firstRestartStore)
        XCTAssertFalse(environment.orderMachine === firstRestartOrderMachine)
    }
}
