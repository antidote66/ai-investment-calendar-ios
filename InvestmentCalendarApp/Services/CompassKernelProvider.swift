import Foundation
import SwiftUI

enum CompassDeliveryTier: String, CaseIterable, Identifiable, Codable {
    case mustDeliver
    case majorRelevant
    case watchNode
    case muted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mustDeliver: return "盘中 · 必达"
        case .majorRelevant: return "重大 · 与你相关"
        case .watchNode: return "关注 · 节点"
        case .muted: return "已折叠 · 低信号"
        }
    }

    var shortTitle: String {
        switch self {
        case .mustDeliver: return "必达"
        case .majorRelevant: return "重大"
        case .watchNode: return "关注"
        case .muted: return "折叠"
        }
    }

    var tint: Color {
        switch self {
        case .mustDeliver: return AppTheme.vermilion
        case .majorRelevant: return AppTheme.amber
        case .watchNode: return AppTheme.sumiBlue
        case .muted: return AppTheme.mutedInk
        }
    }
}

struct CompassRegime: Hashable {
    var title: String
    var thesis: String
    var confidence: Double
    var nextNode: String
    var activeDrivers: [ExposureDriver]
}

struct CompassSignal: Identifiable, Hashable {
    var id: String
    var title: String
    var detail: String
    var date: Date
    var tier: CompassDeliveryTier
    var score: Double
    var reason: String
    var sourceName: String
    var relatedCode: String?
    var event: CalendarEvent?
    var drivers: [ExposureDriver]
    var holdings: [WatchStock]

    var dayText: String {
        DateKeys.displayDay.string(from: date)
    }
}

struct CompassBriefing: Hashable {
    var regime: CompassRegime
    var signals: [CompassSignal]

    func signals(in tier: CompassDeliveryTier) -> [CompassSignal] {
        signals.filter { $0.tier == tier }
    }

    var actionableSignals: [CompassSignal] {
        signals.filter { $0.tier != .muted }
    }
}

enum CompassKernelProvider {
    static func briefing(
        events: [CalendarEvent],
        watchlist: [WatchStock],
        marginSnapshots: [String: MarginSnapshot]
    ) -> CompassBriefing {
        let drivers = ExposureGraphProvider.drivers(for: watchlist, marginSnapshots: marginSnapshots)
        let eventSignals = calendarSignals(events: events, watchlist: watchlist, drivers: drivers)
        let syntheticSignals = syntheticSignals(watchlist: watchlist, marginSnapshots: marginSnapshots, drivers: drivers)
        let signals = (eventSignals + syntheticSignals).sorted { lhs, rhs in
            if lhs.tier != rhs.tier { return tierRank(lhs.tier) < tierRank(rhs.tier) }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.date < rhs.date
        }
        return CompassBriefing(
            regime: regime(events: events, watchlist: watchlist, marginSnapshots: marginSnapshots, drivers: drivers, signals: signals),
            signals: signals
        )
    }

    private static func calendarSignals(events: [CalendarEvent], watchlist: [WatchStock], drivers: [ExposureDriver]) -> [CompassSignal] {
        let today = DateKeys.calendar.startOfDay(for: Date())
        let horizon = DateKeys.calendar.date(byAdding: .day, value: 21, to: today) ?? today
        return events
            .filter { $0.date >= today && $0.date < horizon }
            .map { event in
                signal(for: event, watchlist: watchlist, drivers: drivers, today: today)
            }
    }

    private static func syntheticSignals(
        watchlist: [WatchStock],
        marginSnapshots: [String: MarginSnapshot],
        drivers: [ExposureDriver]
    ) -> [CompassSignal] {
        var result: [CompassSignal] = []

        if let hottest = marginSnapshots.values.sorted(by: { $0.temperatureScore > $1.temperatureScore }).first,
           hottest.temperature != .cool {
            let driverLinks = drivers.filter { $0.id == "margin-leverage" }
            let stock = watchlist.first { $0.code == hottest.code }
            let tier: CompassDeliveryTier = hottest.temperature == .crowded ? .mustDeliver : .majorRelevant
            result.append(CompassSignal(
                id: "synthetic-margin-\(hottest.code)-\(hottest.dateText)",
                title: "\(hottest.name) · 两融杠杆\(hottest.temperature.title)",
                detail: "融资余额占流通市值 \(formatPercent(hottest.financingBalanceRatio))，近10日融资净买入 \(formatAmount(hottest.financingNetBuy10D))。这不是方向预测，是事件日前后的脆弱性提示。",
                date: Date(),
                tier: tier,
                score: max(70, hottest.temperatureScore),
                reason: "两融温度进入\(hottest.temperature.title)区，需和公告/财报/宏观节点一起看。",
                sourceName: hottest.sourceName,
                relatedCode: hottest.code,
                event: nil,
                drivers: driverLinks,
                holdings: stock.map { [$0] } ?? []
            ))
        }

        if let concentration = ExposureGraphProvider.hiddenConcentration(for: drivers) {
            let holdings = watchlist.filter { stock in
                concentration.driver.edges.contains { $0.code == stock.displayCode || $0.code == stock.code }
            }
            result.append(CompassSignal(
                id: "synthetic-concentration-\(concentration.driver.id)",
                title: concentration.title,
                detail: concentration.detail,
                date: Date(),
                tier: .majorRelevant,
                score: 76 + Double(concentration.driver.reliableEdgeCount * 3),
                reason: "多只持仓汇聚同一稳定驱动，分散度被高估。",
                sourceName: "罗盘内核",
                relatedCode: nil,
                event: nil,
                drivers: [concentration.driver],
                holdings: holdings
            ))
        }

        return result
    }

    private static func signal(
        for event: CalendarEvent,
        watchlist: [WatchStock],
        drivers: [ExposureDriver],
        today: Date
    ) -> CompassSignal {
        let matchedHoldings = holdings(for: event, watchlist: watchlist)
        let matchedDrivers = linkedDrivers(for: event, drivers: drivers)
        var score = baseScore(for: event)
        score += Double(matchedHoldings.count) * 24
        score += Double(matchedDrivers.filter { $0.reliableEdgeCount > 0 }.count) * 8
        if matchedDrivers.contains(where: \.hasHiddenConcentration) { score += 10 }
        score += dateUrgency(event.date, today: today)
        if event.category == .usMacro || event.category == .chinaMacro, matchedDrivers.isEmpty, matchedHoldings.isEmpty {
            score = min(score, 34)
        }

        let tier = tier(for: score, event: event, matchedDrivers: matchedDrivers, matchedHoldings: matchedHoldings)
        return CompassSignal(
            id: "event-\(event.id)-\(tier.rawValue)",
            title: event.title,
            detail: event.detail,
            date: event.date,
            tier: tier,
            score: score,
            reason: reason(for: event, tier: tier, drivers: matchedDrivers, holdings: matchedHoldings),
            sourceName: event.sourceName,
            relatedCode: event.relatedCode,
            event: event,
            drivers: matchedDrivers,
            holdings: matchedHoldings
        )
    }

    private static func regime(
        events: [CalendarEvent],
        watchlist: [WatchStock],
        marginSnapshots: [String: MarginSnapshot],
        drivers: [ExposureDriver],
        signals: [CompassSignal]
    ) -> CompassRegime {
        if let crowded = marginSnapshots.values.first(where: { $0.temperature == .crowded }) {
            return CompassRegime(
                title: "杠杆拥挤",
                thesis: "\(crowded.name) 两融温度进入拥挤区，事件日前后先看资金脆弱性。",
                confidence: 0.78,
                nextNode: signals.first?.title ?? "等待两融和公告更新",
                activeDrivers: drivers.filter { $0.id == "margin-leverage" }
            )
        }

        if let realYield = drivers.first(where: { $0.id == "real-yield" && $0.hasHiddenConcentration }) {
            return CompassRegime(
                title: "高利率更久",
                thesis: "实际利率是当前组合最隐蔽的共同驱动，CPI/FOMC 会先影响这个节点，再传导到持仓。",
                confidence: 0.74,
                nextNode: nearestMacroNode(events: events) ?? signals.first?.title ?? "等待 FOMC / CPI",
                activeDrivers: [realYield]
            )
        }

        if let copper = drivers.first(where: { $0.id == "copper" && $0.reliableEdgeCount >= 2 }) {
            return CompassRegime(
                title: "资源共振",
                thesis: "铜价节点连接多只资源股，商品价格比普通公告更能解释同步波动。",
                confidence: 0.66,
                nextNode: signals.first?.title ?? "等待商品和宏观数据",
                activeDrivers: [copper]
            )
        }

        return CompassRegime(
            title: "低噪音跟踪",
            thesis: "当前没有压倒性的共同驱动，按披露日程、重大合同和两融温度逐项验证。",
            confidence: 0.56,
            nextNode: signals.first?.title ?? "等待新事件",
            activeDrivers: Array(drivers.prefix(2))
        )
    }

    private static func baseScore(for event: CalendarEvent) -> Double {
        var score: Double
        switch event.importance {
        case .high: score = 58
        case .normal: score = 38
        case .low: score = 15
        }

        switch event.category {
        case .fomc, .cpi:
            score += 26
        case .announcement:
            score += 20
        case .stockCalendar:
            score += 18
        case .usMacro, .chinaMacro:
            score += event.importance == .high ? 14 : 0
        }
        return score
    }

    private static func tier(
        for score: Double,
        event: CalendarEvent,
        matchedDrivers: [ExposureDriver],
        matchedHoldings: [WatchStock]
    ) -> CompassDeliveryTier {
        if score >= 86 { return .mustDeliver }
        if score >= 64 { return .majorRelevant }
        if score >= 42 { return .watchNode }
        if event.category == .announcement && !matchedHoldings.isEmpty { return .watchNode }
        if matchedDrivers.contains(where: \.hasHiddenConcentration) { return .majorRelevant }
        return .muted
    }

    private static func tierRank(_ tier: CompassDeliveryTier) -> Int {
        switch tier {
        case .mustDeliver: return 0
        case .majorRelevant: return 1
        case .watchNode: return 2
        case .muted: return 3
        }
    }

    private static func holdings(for event: CalendarEvent, watchlist: [WatchStock]) -> [WatchStock] {
        guard let relatedCode = event.relatedCode else { return [] }
        return watchlist.filter { stock in
            stock.code == relatedCode || stock.displayCode == relatedCode
        }
    }

    private static func linkedDrivers(for event: CalendarEvent, drivers: [ExposureDriver]) -> [ExposureDriver] {
        var linked: [ExposureDriver] = []
        if let relatedCode = event.relatedCode {
            linked += drivers.filter { driver in
                driver.edges.contains { edge in
                    edge.code == relatedCode || edge.code.hasSuffix(relatedCode) || relatedCode.hasSuffix(edge.code)
                }
            }
        }

        let text = "\(event.title) \(event.detail)"
        let keywordLinks: [(String, String)] = [
            ("CPI", "real-yield"),
            ("通胀", "real-yield"),
            ("FOMC", "real-yield"),
            ("利率", "real-yield"),
            ("铜", "copper"),
            ("金", "gold"),
            ("锂", "lithium"),
            ("制冷剂", "refrigerant"),
            ("融资", "margin-leverage"),
            ("两融", "margin-leverage"),
            ("港股", "hk-liquidity"),
            ("南向", "hk-liquidity")
        ]
        let ids = keywordLinks.compactMap { keyword, id in text.localizedCaseInsensitiveContains(keyword) ? id : nil }
        linked += drivers.filter { ids.contains($0.id) }

        switch event.category {
        case .cpi, .fomc:
            linked += drivers.filter { ["real-yield", "gold", "hk-liquidity"].contains($0.id) }
        case .chinaMacro:
            linked += drivers.filter { ["copper", "lithium", "refrigerant"].contains($0.id) }
        case .usMacro:
            linked += drivers.filter { ["real-yield", "gold"].contains($0.id) }
        case .announcement, .stockCalendar:
            break
        }

        var result: [String: ExposureDriver] = [:]
        for driver in linked {
            result[driver.id] = driver
        }
        return Array(result.values).sorted { $0.order < $1.order }
    }

    private static func dateUrgency(_ date: Date, today: Date) -> Double {
        let day = DateKeys.calendar.startOfDay(for: date)
        let days = DateKeys.calendar.dateComponents([.day], from: today, to: day).day ?? 99
        if days <= 0 { return 12 }
        if days <= 1 { return 10 }
        if days <= 7 { return 5 }
        return 0
    }

    private static func reason(
        for event: CalendarEvent,
        tier: CompassDeliveryTier,
        drivers: [ExposureDriver],
        holdings: [WatchStock]
    ) -> String {
        if !holdings.isEmpty {
            return "直接命中自选股：\(holdings.map(\.name).joined(separator: "、"))。"
        }
        if let driver = drivers.first(where: \.hasHiddenConcentration) {
            return "命中隐藏集中度节点：\(driver.title)。"
        }
        if !drivers.isEmpty {
            return "命中驱动节点：\(drivers.map(\.title).prefix(2).joined(separator: "、"))。"
        }
        if tier == .muted {
            return "与当前持仓和核心驱动关联弱，折叠保留。"
        }
        return event.importance == .high ? "高优先级事件，等待后续验证。" : "进入观察队列。"
    }

    private static func nearestMacroNode(events: [CalendarEvent]) -> String? {
        let today = DateKeys.calendar.startOfDay(for: Date())
        return events
            .filter { $0.date >= today && ($0.category == .fomc || $0.category == .cpi) }
            .sorted { $0.date < $1.date }
            .first
            .map { "\(DateKeys.displayDay.string(from: $0.date)) \($0.title)" }
    }

    private static func formatAmount(_ value: Double) -> String {
        let absolute = abs(value)
        let sign = value < 0 ? "-" : ""
        if absolute >= 100_000_000 {
            return "\(sign)\(String(format: "%.2f", absolute / 100_000_000))亿"
        }
        if absolute >= 10_000 {
            return "\(sign)\(String(format: "%.0f", absolute / 10_000))万"
        }
        return "\(sign)\(String(format: "%.0f", absolute))"
    }

    private static func formatPercent(_ value: Double?) -> String {
        guard let value else { return "缺失" }
        return "\(String(format: "%.2f", value))%"
    }
}
