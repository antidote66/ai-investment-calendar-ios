import Combine
import Foundation

@MainActor
final class InvestmentCalendarStore: ObservableObject {
    @Published var events: [CalendarEvent] = MacroCalendarProvider.seedEvents()
    @Published var watchlist: [WatchStock] = []
    @Published var selectedDate: Date = Date()
    @Published var visibleMonth: Date = Date()
    @Published var isRefreshing = false
    @Published var isAnalyzingAI = false
    @Published var lastUpdated: Date?
    @Published var statusMessage: String?
    @Published var aiStatusMessage: String?
    @Published var aiProviderKind: AIProviderKind = .localRule
    @Published var aiInsight: AIInsight = .empty

    private let watchlistKey = "watchlist.v1"
    private let aiProviderKey = "ai.provider.v1"

    init() {
        loadWatchlist()
        loadAIProvider()
        aiInsight = AIAnalysisProvider.localInsight(events: events, watchlist: watchlist)
    }

    func refresh() async {
        isRefreshing = true
        statusMessage = nil

        let macroSeeds = MacroCalendarProvider.seedEvents()
        async let onlineMacro = MacroCalendarProvider.fetchOnlineEvents()
        async let announcements = AnnouncementProvider.fetch(for: watchlist)

        let fetchedMacro = await onlineMacro
        let fetchedAnnouncements = await announcements
        let all = macroSeeds + fetchedMacro + fetchedAnnouncements
        events = deduplicated(all).sorted {
            if $0.date == $1.date { return $0.importance > $1.importance }
            return $0.date < $1.date
        }
        lastUpdated = Date()
        isRefreshing = false

        let announcementCount = events.filter { $0.category == .announcement }.count
        let reportCount = events.filter { $0.category == .stockCalendar }.count
        statusMessage = "已更新：\(announcementCount) 条公告，\(reportCount) 条财报披露日期。"
        await refreshAIAnalysis()
    }

    func refreshAIAnalysis() async {
        isAnalyzingAI = true
        let insight = await AIAnalysisProvider.analyze(events: events, watchlist: watchlist, provider: aiProviderKind)
        aiInsight = insight
        aiStatusMessage = insight.sourceNote
        isAnalyzingAI = false
    }

    func events(on date: Date) -> [CalendarEvent] {
        let key = DateKeys.day.string(from: date)
        return events
            .filter { $0.dayKey == key }
            .sorted {
                if $0.importance == $1.importance { return $0.date < $1.date }
                return $0.importance > $1.importance
            }
    }

    func events(in month: Date) -> [String: [CalendarEvent]] {
        let components = DateKeys.calendar.dateComponents([.year, .month], from: month)
        return Dictionary(grouping: events.filter { event in
            let value = DateKeys.calendar.dateComponents([.year, .month], from: event.date)
            return value.year == components.year && value.month == components.month
        }, by: \.dayKey)
    }

    func upcomingFocusEvents(from start: Date = Date(), days: Int = 21, limit: Int = 6) -> [CalendarEvent] {
        let startDay = DateKeys.calendar.startOfDay(for: start)
        let endDay = DateKeys.calendar.date(byAdding: .day, value: days, to: startDay) ?? startDay
        return events
            .filter { event in
                event.date >= startDay
                    && event.date < endDay
                    && isMajorDisplayEvent(event)
            }
            .sorted {
                if $0.date == $1.date { return $0.importance > $1.importance }
                return $0.date < $1.date
            }
            .prefix(limit)
            .map { $0 }
    }

    func majorEvents(on date: Date) -> [CalendarEvent] {
        let key = DateKeys.day.string(from: date)
        return events
            .filter { $0.dayKey == key && isMajorDisplayEvent($0) }
            .sorted {
                if $0.importance == $1.importance { return $0.date < $1.date }
                return $0.importance > $1.importance
            }
    }

    func nextEvent(for stock: WatchStock) -> CalendarEvent? {
        let today = DateKeys.calendar.startOfDay(for: Date())
        let codes = Set([stock.code, stock.displayCode])
        return events
            .filter { event in
                guard let relatedCode = event.relatedCode else { return false }
                return codes.contains(relatedCode) && event.date >= today
            }
            .sorted {
                if $0.date == $1.date { return $0.importance > $1.importance }
                return $0.date < $1.date
            }
            .first
    }

    func visibleMonthCounts() -> (macro: Int, stock: Int, disclosure: Int) {
        let monthEvents = events(in: visibleMonth).values.flatMap { $0 }
        let macro = monthEvents.filter { [.fomc, .usMacro, .chinaMacro, .cpi].contains($0.category) }.count
        let stock = monthEvents.filter { $0.category == .announcement }.count
        let disclosure = monthEvents.filter { $0.category == .stockCalendar }.count
        return (macro, stock, disclosure)
    }

    func addStock(_ stock: WatchStock) {
        guard !watchlist.contains(where: { $0.market == stock.market && $0.code == stock.code }) else { return }
        watchlist.append(stock)
        saveWatchlist()
        aiInsight = AIAnalysisProvider.localInsight(events: events, watchlist: watchlist)
    }

    func resolveAStock(keyword: String) async -> WatchStock? {
        await StockLookupProvider.resolveAStock(keyword: keyword)
    }

    func deleteStocks(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            watchlist.remove(at: index)
        }
        saveWatchlist()
        aiInsight = AIAnalysisProvider.localInsight(events: events, watchlist: watchlist)
    }

    func setAIProvider(_ provider: AIProviderKind) async {
        aiProviderKind = provider
        UserDefaults.standard.set(provider.rawValue, forKey: aiProviderKey)
        await refreshAIAnalysis()
    }

    func saveAIAPIKey(_ value: String, for provider: AIProviderKind) async {
        AIProviderKeychain.save(value, for: provider)
        if aiProviderKind == provider {
            await refreshAIAnalysis()
        }
    }

    func deleteAIAPIKey(for provider: AIProviderKind) async {
        AIProviderKeychain.delete(for: provider)
        if aiProviderKind == provider {
            await refreshAIAnalysis()
        }
    }

    func hasAIAPIKey(for provider: AIProviderKind) -> Bool {
        AIProviderKeychain.hasKey(for: provider)
    }

    func aiProviderStatusText() -> String {
        if aiProviderKind == .localRule {
            return "本地规则稳定运行"
        }
        if hasAIAPIKey(for: aiProviderKind) {
            return "\(aiProviderKind.title) 已配置"
        }
        return "\(aiProviderKind.title) 未配置 Key，使用本地规则"
    }

    private func loadWatchlist() {
        guard let data = UserDefaults.standard.data(forKey: watchlistKey),
              let decoded = try? JSONDecoder().decode([WatchStock].self, from: data),
              !decoded.isEmpty else {
            watchlist = WatchStock.defaults
            saveWatchlist()
            return
        }
        watchlist = decoded
        for stock in WatchStock.defaults where !watchlist.contains(where: { $0.market == stock.market && $0.code == stock.code }) {
            watchlist.append(stock)
        }
        saveWatchlist()
    }

    private func loadAIProvider() {
        guard let raw = UserDefaults.standard.string(forKey: aiProviderKey),
              let provider = AIProviderKind(rawValue: raw) else {
            aiProviderKind = .localRule
            return
        }
        aiProviderKind = provider
    }

    private func saveWatchlist() {
        guard let data = try? JSONEncoder().encode(watchlist) else { return }
        UserDefaults.standard.set(data, forKey: watchlistKey)
    }

    private func deduplicated(_ values: [CalendarEvent]) -> [CalendarEvent] {
        var result: [String: CalendarEvent] = [:]
        for value in values {
            result[value.id] = value
        }
        return Array(result.values)
    }

    private func isMajorDisplayEvent(_ event: CalendarEvent) -> Bool {
        switch event.category {
        case .stockCalendar:
            return true
        case .announcement:
            return event.importance == .high
        case .fomc, .cpi:
            return true
        case .usMacro, .chinaMacro:
            return event.importance == .high
        }
    }
}
