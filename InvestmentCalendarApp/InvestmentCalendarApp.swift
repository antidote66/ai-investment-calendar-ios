import SwiftUI

@main
struct InvestmentCalendarApp: App {
    @StateObject private var store = InvestmentCalendarStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
