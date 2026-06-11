import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: InvestmentCalendarStore

    var body: some View {
        TabView {
            CalendarScreen()
            AIWorkspaceScreen()
            WatchlistView()
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .background(AppTheme.paper)
        .tint(AppTheme.vermilion)
        .task {
            await store.refresh()
        }
    }
}
